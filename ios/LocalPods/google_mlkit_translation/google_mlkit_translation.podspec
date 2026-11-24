# Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
# SPDX-License-Identifier: MIT

Pod::Spec.new do |s|
  s.name             = 'google_mlkit_translation'
  s.version          = '0.13.1'
  s.summary          = 'No-op iOS simulator-safe stub for google_mlkit_translation.'
  s.description      = 'Replaces the upstream MLKit binary pod on iOS (where Apple Foundation Models and Apple Translation are used) so arm64 iOS Simulators link cleanly.'
  s.homepage         = 'https://github.com/brokengoose/FediCaptionMobile'
  s.license          = { :type => 'MIT' }
  s.author           = { 'brokengoose' => 'brokengoose@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency       'Flutter'
  s.platform         = :ios, '15.0'
end
