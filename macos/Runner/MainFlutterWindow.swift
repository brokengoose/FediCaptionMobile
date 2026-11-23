// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import Cocoa
import FlutterMacOS
import NaturalLanguage
import SwiftUI
#if canImport(Translation)
import Translation
#endif

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 520, height: 600)
    self.setContentSize(NSSize(width: 1160, height: 820))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    AppleTranslationBridge.register(
      with: flutterViewController.engine.binaryMessenger,
      window: self
    )

    super.awakeFromNib()
  }
}

private enum AppleTranslationBridge {
  static let channelName = "io.github.brokengoose.fedicaption/apple_translation"

  static func register(with messenger: FlutterBinaryMessenger, window: NSWindow) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak window] call, result in
      switch call.method {
      case "isSupported":
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
          result(true)
        } else {
          result(false)
        }
        #else
        result(false)
        #endif

      case "detectLanguage":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
          result(nil)
          return
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let lang = recognizer.dominantLanguage, lang != .undetermined {
          result(lang.rawValue)
        } else {
          result(nil)
        }

      case "translate":
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
          guard let args = call.arguments as? [String: Any],
                let text = args["text"] as? String,
                let targetCode = args["targetLanguage"] as? String else {
            result(FlutterError(
              code: "INVALID_ARGS",
              message: "Missing text or targetLanguage.",
              details: nil
            ))
            return
          }
          let rawSource = args["sourceLanguage"] as? String
          Task { @MainActor in
            await performTranslation(
              text: text,
              sourceCode: rawSource,
              targetCode: targetCode,
              window: window,
              result: result
            )
          }
          return
        }
        #endif
        result(FlutterError(
          code: "UNAVAILABLE",
          message: "Apple Translation requires macOS 15.0 or newer.",
          details: nil
        ))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  #if canImport(Translation)
  @available(macOS 15.0, *)
  @MainActor
  private static func performTranslation(
    text: String,
    sourceCode: String?,
    targetCode: String,
    window: NSWindow?,
    result: @escaping FlutterResult
  ) async {
    var resolvedSource = sourceCode?.trimmingCharacters(in: .whitespacesAndNewlines)
    if resolvedSource == nil || resolvedSource!.isEmpty {
      let recognizer = NLLanguageRecognizer()
      recognizer.processString(text)
      if let lang = recognizer.dominantLanguage, lang != .undetermined {
        resolvedSource = lang.rawValue
      }
    }

    guard let sourceLangCode = resolvedSource, !sourceLangCode.isEmpty else {
      result(FlutterError(
        code: "UNKNOWN_LANGUAGE",
        message: "Could not determine the post language.",
        details: nil
      ))
      return
    }

    let sourceLang = Locale.Language(identifier: sourceLangCode)
    let targetLang = Locale.Language(identifier: targetCode)
    let availability = LanguageAvailability()
    let status = await availability.status(from: sourceLang, to: targetLang)

    switch status {
    case .unsupported:
      result(FlutterError(
        code: "UNSUPPORTED_LANGUAGE",
        message: "Apple Translation does not support translating from \(sourceLangCode) to \(targetCode).",
        details: nil
      ))
      return

    case .installed:
      if #available(macOS 26.0, *) {
        do {
          let session = TranslationSession(installedSource: sourceLang, target: targetLang)
          let response = try await session.translate(text)
          result(response.targetText)
        } catch {
          result(FlutterError(
            code: "TRANSLATION_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
        return
      }
      fallthrough

    case .supported:
      guard let hostContainer = window?.contentView else {
        result(FlutterError(
          code: "NO_WINDOW",
          message: "No window available to download Apple Translation language pack.",
          details: nil
        ))
        return
      }
      var completed = false
      var hostingView: NSHostingView<MacTranslationTaskView>?
      let config = TranslationSession.Configuration(source: sourceLang, target: targetLang)
      let taskView = MacTranslationTaskView(
        configuration: config,
        text: text
      ) { outcome in
        guard !completed else { return }
        completed = true
        hostingView?.removeFromSuperview()
        hostingView = nil
        switch outcome {
        case .success(let translated):
          result(translated)
        case .failure(let error):
          result(FlutterError(
            code: "TRANSLATION_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
      let view = NSHostingView(rootView: taskView)
      view.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
      hostingView = view
      hostContainer.addSubview(view)

    @unknown default:
      result(FlutterError(
        code: "UNAVAILABLE",
        message: "Apple Translation status is unknown.",
        details: nil
      ))
    }
  }
  #endif
}

#if canImport(Translation)
@available(macOS 15.0, *)
private struct MacTranslationTaskView: View {
  let configuration: TranslationSession.Configuration
  let text: String
  let onComplete: @MainActor (Result<String, Error>) -> Void

  var body: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .translationTask(configuration) { session in
        do {
          try await session.prepareTranslation()
          let response = try await session.translate(text)
          await MainActor.run {
            onComplete(.success(response.targetText))
          }
        } catch {
          await MainActor.run {
            onComplete(.failure(error))
          }
        }
      }
  }
}
#endif
