// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import Flutter
import NaturalLanguage
import SwiftUI
import UIKit
#if canImport(Translation)
import Translation
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AppleTranslationBridge.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
  }
}

private enum AppleTranslationBridge {
  static let channelName = "io.github.brokengoose.fedicaption/apple_translation"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
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
        if #available(iOS 18.0, *) {
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
              result: result
            )
          }
          return
        }
        #endif
        result(FlutterError(
          code: "UNAVAILABLE",
          message: "Apple Translation requires iOS 18.0 or newer.",
          details: nil
        ))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  #if canImport(Translation)
  @available(iOS 18.0, *)
  @MainActor
  private static func performTranslation(
    text: String,
    sourceCode: String?,
    targetCode: String,
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
      if #available(iOS 26.0, *) {
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
      guard let rootVC = activeRootViewController() else {
        result(FlutterError(
          code: "NO_WINDOW",
          message: "No window available to download Apple Translation language pack.",
          details: nil
        ))
        return
      }
      var completed = false
      var hostVC: UIHostingController<IosTranslationTaskView>?
      let config = TranslationSession.Configuration(source: sourceLang, target: targetLang)
      let taskView = IosTranslationTaskView(
        configuration: config,
        text: text
      ) { outcome in
        guard !completed else { return }
        completed = true
        hostVC?.willMove(toParent: nil)
        hostVC?.view.removeFromSuperview()
        hostVC?.removeFromParent()
        hostVC = nil
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
      let controller = UIHostingController(rootView: taskView)
      controller.view.backgroundColor = .clear
      controller.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
      hostVC = controller
      rootVC.addChild(controller)
      rootVC.view.addSubview(controller.view)
      controller.didMove(toParent: rootVC)

    @unknown default:
      result(FlutterError(
        code: "UNAVAILABLE",
        message: "Apple Translation status is unknown.",
        details: nil
      ))
    }
  }

  @MainActor
  private static func activeRootViewController() -> UIViewController? {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
          return key.rootViewController
        }
        if let first = windowScene.windows.first {
          return first.rootViewController
        }
      }
    }
    return nil
  }
  #endif
}

#if canImport(Translation)
@available(iOS 18.0, *)
private struct IosTranslationTaskView: View {
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
