#include "flutter_window.h"

#include <wincrypt.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

bool IsTrustedForServerAuth(PCCERT_CONTEXT cert) {
  DWORD usage_size = 0;
  if (!::CertGetEnhancedKeyUsage(cert, 0, nullptr, &usage_size)) {
    return ::GetLastError() == static_cast<DWORD>(CRYPT_E_NOT_FOUND);
  }
  if (usage_size == 0) {
    return ::GetLastError() == static_cast<DWORD>(CRYPT_E_NOT_FOUND);
  }
  std::vector<uint8_t> buf(usage_size);
  auto* usage = reinterpret_cast<PCERT_ENHKEY_USAGE>(buf.data());
  if (!::CertGetEnhancedKeyUsage(cert, 0, usage, &usage_size)) {
    return false;
  }
  if (usage->cUsageIdentifier == 0) {
    // CRYPT_E_NOT_FOUND means valid for all purposes; S_OK means explicitly
    // disabled for all purposes in the Windows certificate store.
    return ::GetLastError() == static_cast<DWORD>(CRYPT_E_NOT_FOUND);
  }
  for (DWORD i = 0; i < usage->cUsageIdentifier; ++i) {
    const char* oid = usage->rgpszUsageIdentifier[i];
    if (oid && (std::strcmp(oid, szOID_PKIX_KP_SERVER_AUTH) == 0 ||
                std::strcmp(oid, szOID_ANY_ENHANCED_KEY_USAGE) == 0)) {
      return true;
    }
  }
  return false;
}

flutter::EncodableList LoadWindowsTrustedRootCerts() {
  flutter::EncodableList certs;
  HCERTSTORE store = ::CertOpenSystemStoreW(0, L"ROOT");
  if (!store) {
    return certs;
  }

  PCCERT_CONTEXT cert = nullptr;
  while ((cert = ::CertEnumCertificatesInStore(store, cert)) != nullptr) {
    if (!cert->pbCertEncoded || cert->cbCertEncoded == 0) {
      continue;
    }
    // Only include currently valid (non-expired) X.509 root certificates
    // permitted by Windows for TLS server authentication.
    if (cert->pCertInfo &&
        ::CertVerifyTimeValidity(nullptr, cert->pCertInfo) != 0) {
      continue;
    }
    if (!IsTrustedForServerAuth(cert)) {
      continue;
    }
    std::vector<uint8_t> der(
        cert->pbCertEncoded, cert->pbCertEncoded + cert->cbCertEncoded);
    certs.emplace_back(std::move(der));
  }

  ::CertCloseStore(store, 0);
  return certs;
}

}  // namespace

extern "C" {

__declspec(dllexport) void* fedicaption_alloc(int32_t size) {
  if (size <= 0) return nullptr;
  return std::malloc(static_cast<size_t>(size));
}

__declspec(dllexport) void fedicaption_free(void* ptr) {
  if (ptr) {
    std::free(ptr);
  }
}

// Verifies a peer X.509 DER certificate against the native Windows CryptoAPI
// SSL chain policy using local/cached stores and certificates (cache-only URL
// retrieval avoids blocking the UI isolate on network AIA/CRL fetches), with
// exact hostname matching.
// Returns 1 if Windows trusts the certificate for |host_utf8|, else 0.
__declspec(dllexport) int32_t fedicaption_verify_windows_cert(
    const uint8_t* der, int32_t der_len, const uint8_t* host_utf8,
    int32_t host_len) {
  if (!der || der_len <= 0 || !host_utf8 || host_len <= 0) {
    return 0;
  }

  int wide_len = ::MultiByteToWideChar(
      CP_UTF8, 0, reinterpret_cast<const char*>(host_utf8), host_len, nullptr,
      0);
  if (wide_len <= 0) {
    return 0;
  }
  std::wstring wide_host(static_cast<size_t>(wide_len), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, reinterpret_cast<const char*>(host_utf8),
                        host_len, wide_host.data(), wide_len);

  PCCERT_CONTEXT cert = ::CertCreateCertificateContext(
      X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, der,
      static_cast<DWORD>(der_len));
  if (!cert) {
    return 0;
  }

  LPSTR server_auth_usages[] = {
      const_cast<LPSTR>(szOID_PKIX_KP_SERVER_AUTH),
  };
  CERT_CHAIN_PARA chain_para = {};
  chain_para.cbSize = sizeof(chain_para);
  chain_para.RequestedUsage.dwType = USAGE_MATCH_TYPE_AND;
  chain_para.RequestedUsage.Usage.cUsageIdentifier = 1;
  chain_para.RequestedUsage.Usage.rgpszUsageIdentifier = server_auth_usages;

  PCCERT_CHAIN_CONTEXT chain_ctx = nullptr;
  BOOL chain_ok = ::CertGetCertificateChain(
      nullptr, cert, nullptr, nullptr, &chain_para,
      CERT_CHAIN_CACHE_END_CERT | CERT_CHAIN_CACHE_ONLY_URL_RETRIEVAL,
      nullptr, &chain_ctx);
  if (!chain_ok || !chain_ctx) {
    ::CertFreeCertificateContext(cert);
    return 0;
  }

  SSL_EXTRA_CERT_CHAIN_POLICY_PARA ssl_para = {};
  ssl_para.cbStruct = sizeof(ssl_para);
  ssl_para.dwAuthType = AUTHTYPE_SERVER;
  ssl_para.pwszServerName = wide_host.data();

  CERT_CHAIN_POLICY_PARA policy_para = {};
  policy_para.cbSize = sizeof(policy_para);
  policy_para.pvExtraPolicyPara = &ssl_para;

  CERT_CHAIN_POLICY_STATUS policy_status = {};
  policy_status.cbSize = sizeof(policy_status);

  BOOL policy_ok = ::CertVerifyCertificateChainPolicy(
      CERT_CHAIN_POLICY_SSL, chain_ctx, &policy_para, &policy_status);
  int32_t trusted = (policy_ok && policy_status.dwError == 0) ? 1 : 0;

  ::CertFreeCertificateChain(chain_ctx);
  ::CertFreeCertificateContext(cert);
  return trusted;
}

}  // extern "C"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  cert_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "io.github.brokengoose.fedicaption/windows_certs",
          &flutter::StandardMethodCodec::GetInstance());
  cert_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "getTrustedRootCerts") {
          result->Success(flutter::EncodableValue(LoadWindowsTrustedRootCerts()));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  cert_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
