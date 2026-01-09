//
//  WhisperManager.swift
//  dial8 MacOS
//
//  Created by Liam Alizadeh on 10/18/24.
//  Modified for Lightning Whisper MLX integration
//

/// WhisperManager handles all aspects of the Whisper speech recognition system.
///
/// This singleton service provides comprehensive speech recognition functionality
/// using Lightning Whisper MLX for Apple Silicon Macs.
///
/// Supported Models:
/// - tiny: Fastest, lowest accuracy
/// - small: Good balance of speed and accuracy
/// - distil-small.en: Optimized English model (default)
/// - base: Basic model
/// - medium: Higher accuracy
/// - distil-medium.en: Optimized medium English model
/// - large: High accuracy
/// - large-v2: Improved large model
/// - distil-large-v2: Optimized large v2
/// - large-v3: Latest large model
/// - distil-large-v3: Optimized large v3

import Foundation
import Combine
import AppKit

// Model display information for UI
struct ModelDisplayInfo {
    let id: String
    let displayName: String
    let icon: String
    let description: String
    let recommendation: String?
}

struct WhisperModelInfo: Identifiable {
    let id: String
    let name: String
    let fileName: String
    let size: String
    let fileSize: UInt64
    var isAvailable: Bool
    var isSelected: Bool
    let description: String
    var displayInfo: ModelDisplayInfo
}

/// Represents a timestamped segment from Whisper transcription
struct WhisperTranscriptionSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    var duration: TimeInterval {
        return endTime - startTime
    }
}

class WhisperManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = WhisperManager()

    // Published properties for UI updates
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var availableModels: [WhisperModelInfo] = []
    @Published var selectedModelSize: String = "distil-small.en"  // Default to distil-small.en

    // Process management
    private var processQueue = DispatchQueue(label: "com.dial8.whisper.process", qos: .userInitiated)
    private let processLock = NSLock()
    private var lastModelUseTime: Date?
    private let modelReloadThreshold: TimeInterval = 300 // 5 minutes

    private var cancellables = Set<AnyCancellable>()

    weak var globalHotkeyManager: GlobalHotkeyManager?

    // Lightning Whisper MLX model definitions
    private static let lightningWhisperModels: [(id: String, displayName: String, description: String, recommendation: String?, icon: String)] = [
        ("tiny", "Tiny", "Fastest model with basic accuracy. Good for quick transcriptions.", nil, "hare"),
        ("base", "Base", "Basic model with reasonable accuracy.", nil, "tortoise"),
        ("small", "Small", "Good balance of speed and accuracy.", nil, "speedometer"),
        ("distil-small.en", "Distil Small (English)", "Optimized English model. Fast and accurate for English speech.", "Recommended for English", "star.circle"),
        ("medium", "Medium", "Higher accuracy with moderate speed.", nil, "gauge.with.dots.needle.50percent"),
        ("distil-medium.en", "Distil Medium (English)", "Optimized medium English model. Better accuracy for English.", nil, "star.circle.fill"),
        ("large", "Large", "High accuracy model. Slower but more accurate.", nil, "scalemass"),
        ("large-v2", "Large V2", "Improved large model with better accuracy.", nil, "scalemass.fill"),
        ("distil-large-v2", "Distil Large V2", "Optimized large v2. Good accuracy with better speed.", nil, "bolt.circle"),
        ("large-v3", "Large V3", "Latest large model. Highest accuracy.", nil, "crown"),
        ("distil-large-v3", "Distil Large V3", "Optimized large v3. Best balance of accuracy and speed.", "Best for professional use", "crown.fill")
    ]

    override init() {
        super.init()
        loadSelectedModel()
        loadAvailableModels()
        setupNotifications()
        // Check if Python and lightning-whisper-mlx are available
        checkPythonEnvironment()
    }

    // Load the previously selected model from UserDefaults
    private func loadSelectedModel() {
        if let savedModel = UserDefaults.standard.string(forKey: "SelectedWhisperModel") {
            selectedModelSize = savedModel
        } else {
            // Default to distil-small.en
            selectedModelSize = "distil-small.en"
            UserDefaults.standard.setValue(selectedModelSize, forKey: "SelectedWhisperModel")
        }
    }

    // Load information about available Whisper models
    private func loadAvailableModels() {
        var modelsInfo: [WhisperModelInfo] = []

        for model in Self.lightningWhisperModels {
            let displayInfo = ModelDisplayInfo(
                id: model.id,
                displayName: model.displayName,
                icon: model.icon,
                description: model.description,
                recommendation: model.recommendation
            )

            let modelInfo = WhisperModelInfo(
                id: model.id,
                name: model.displayName,
                fileName: model.id, // Lightning Whisper MLX uses model ID directly
                size: "",
                fileSize: 0,
                isAvailable: true, // Models are downloaded on-demand by lightning-whisper-mlx
                isSelected: model.id == selectedModelSize,
                description: model.description,
                displayInfo: displayInfo
            )

            modelsInfo.append(modelInfo)
        }

        DispatchQueue.main.async {
            self.availableModels = modelsInfo
            self.isReady = true
        }
    }

    // Check if Python environment is set up correctly
    private func checkPythonEnvironment() {
        processQueue.async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-c", "from lightning_whisper_mlx import LightningWhisperMLX; print('OK')"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if process.terminationStatus == 0 && output.contains("OK") {
                        print("✅ Lightning Whisper MLX is available")
                        self?.isReady = true
                        self?.errorMessage = nil
                    } else {
                        print("⚠️ Lightning Whisper MLX not found")
                        self?.isReady = false
                        self?.errorMessage = "Lightning Whisper MLX is not installed. Run: pip install lightning-whisper-mlx"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Failed to check Python environment: \(error)")
                    self?.isReady = false
                    self?.errorMessage = "Python3 not found. Please install Python 3 and lightning-whisper-mlx."
                }
            }
        }
    }

    // Start the setup process for a given model size
    func startSetup(modelSize: String? = nil) {
        selectedModelSize = modelSize ?? "distil-small.en"
        UserDefaults.standard.setValue(selectedModelSize, forKey: "SelectedWhisperModel")
        loadAvailableModels()
        checkPythonEnvironment()
    }

    // Download model - Lightning Whisper MLX downloads models automatically on first use
    func downloadModel(modelSize: String) {
        // Lightning Whisper MLX downloads models automatically when first used
        // This function now just selects the model and verifies the environment
        DispatchQueue.main.async {
            self.selectModel(modelSize: modelSize)
            self.isDownloading = false
            self.downloadProgress = 1.0
        }
    }

    // Select a different Whisper model
    func selectModel(modelSize: String) {
        selectedModelSize = modelSize
        UserDefaults.standard.setValue(selectedModelSize, forKey: "SelectedWhisperModel")
        loadAvailableModels()
    }

    // Delete a downloaded Whisper model - not applicable for lightning-whisper-mlx
    // Models are managed by the library itself
    func deleteModel(modelSize: String) {
        // Lightning Whisper MLX manages its own model cache
        // This is a no-op for now, but we could add cache clearing functionality
        DispatchQueue.main.async {
            self.errorMessage = "Model cache is managed by Lightning Whisper MLX. Clear cache manually if needed."
        }
    }

    private func setupNotifications() {
        #if os(macOS)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleepNotification(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil as Any?
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil as Any?
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange(_:)),
            name: NSApplication.willResignActiveNotification,
            object: nil as Any?
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil as Any?
        )
        #endif
    }

    @objc private func handleSleepNotification(_ notification: Notification) {
        print("💤 System going to sleep")
        lastModelUseTime = nil
    }

    @objc private func handleWakeNotification(_ notification: Notification) {
        print("⚡️ System waking up")
    }

    @objc private func handleAppStateChange(_ notification: Notification) {
        if notification.name == NSApplication.willResignActiveNotification {
            print("📱 App entering background")
        } else if notification.name == NSApplication.didBecomeActiveNotification {
            print("📱 App becoming active")
        }
    }

    // Get the path to the Python transcription script
    private func getPythonScriptPath() -> URL? {
        return Bundle.main.url(forResource: "lightning_whisper_transcribe", withExtension: "py")
    }

    func transcribe(audioURL: URL, mode: RecordingMode, targetLanguage: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        lastModelUseTime = Date()

        guard isReady else {
            completion(.failure(NSError(domain: "WhisperManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lightning Whisper MLX is not ready. Please check Python installation."])))
            return
        }

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.processLock.lock()
            defer { self.processLock.unlock() }

            // Create a temporary directory for this transcription
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let outputFile = tempDir.appendingPathComponent("transcription")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

            // Get the script path from bundle or use inline Python
            var arguments = [
                "-c",
                """
                import sys
                import os

                try:
                    from lightning_whisper_mlx import LightningWhisperMLX
                except ImportError:
                    print("Error: lightning-whisper-mlx not installed", file=sys.stderr)
                    sys.exit(1)

                model_name = sys.argv[1]
                audio_path = sys.argv[2]
                output_path = sys.argv[3]
                language = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != 'auto' else None

                try:
                    whisper = LightningWhisperMLX(model=model_name, batch_size=12, quant=None)
                    result = whisper.transcribe(audio_path=audio_path, language=language)

                    if isinstance(result, dict):
                        text = result.get('text', '')
                    else:
                        text = str(result)

                    text = text.strip()

                    with open(output_path + '.txt', 'w', encoding='utf-8') as f:
                        f.write(text)

                    print("OK")
                except Exception as e:
                    print(f"Error: {str(e)}", file=sys.stderr)
                    sys.exit(1)
                """,
                self.selectedModelSize,
                audioURL.path,
                outputFile.path
            ]

            // Add language if specified
            if let lang = targetLanguage, lang != "auto" {
                arguments.append(lang)
            } else {
                arguments.append("auto")
            }

            process.arguments = arguments
            process.currentDirectoryURL = tempDir

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "WhisperManager", code: Int(exitCode),
                                userInfo: [NSLocalizedDescriptionKey: "Transcription failed: \(errorOutput)"])
                }

                // Read the transcription
                let transcriptionFile = outputFile.appendingPathExtension("txt")

                if !FileManager.default.fileExists(atPath: transcriptionFile.path) {
                    throw NSError(domain: "WhisperManager", code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Transcription file not found"])
                }

                let transcription = try String(contentsOf: transcriptionFile, encoding: .utf8)

                // Clean up
                try? FileManager.default.removeItem(at: tempDir)

                // Filter and process the transcription
                let filteredTranscription = transcription
                    .components(separatedBy: .newlines)
                    .map { line -> String in
                        line.replacingOccurrences(of: "\\[.*?\\]|\\(.*?\\)|♪.*?♪", with: "", options: .regularExpression)
                            .replacingOccurrences(of: "♪", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                DispatchQueue.main.async {
                    completion(.success(filteredTranscription))
                }
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Transcribe audio with timestamps
    func transcribeWithTimestamps(audioURL: URL, recordingStartTime: Date, targetLanguage: String? = nil, completion: @escaping (Result<[WhisperTranscriptionSegment], Error>) -> Void) {
        lastModelUseTime = Date()

        guard isReady else {
            completion(.failure(NSError(domain: "WhisperManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lightning Whisper MLX is not ready"])))
            return
        }

        processQueue.async { [weak self] in
            guard let self = self else { return }
            self.processLock.lock()
            defer { self.processLock.unlock() }

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let outputFile = tempDir.appendingPathComponent("transcription")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

            var arguments = [
                "-c",
                """
                import sys
                import json

                try:
                    from lightning_whisper_mlx import LightningWhisperMLX
                except ImportError:
                    print("Error: lightning-whisper-mlx not installed", file=sys.stderr)
                    sys.exit(1)

                model_name = sys.argv[1]
                audio_path = sys.argv[2]
                output_path = sys.argv[3]
                language = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != 'auto' else None

                try:
                    whisper = LightningWhisperMLX(model=model_name, batch_size=12, quant=None)
                    result = whisper.transcribe(audio_path=audio_path, language=language)

                    # Save full result as JSON for timestamp parsing
                    with open(output_path + '.json', 'w', encoding='utf-8') as f:
                        json.dump(result, f, ensure_ascii=False)

                    print("OK")
                except Exception as e:
                    print(f"Error: {str(e)}", file=sys.stderr)
                    sys.exit(1)
                """,
                self.selectedModelSize,
                audioURL.path,
                outputFile.path
            ]

            if let lang = targetLanguage, lang != "auto" {
                arguments.append(lang)
            } else {
                arguments.append("auto")
            }

            process.arguments = arguments
            process.currentDirectoryURL = tempDir

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "WhisperManager", code: Int(exitCode),
                                userInfo: [NSLocalizedDescriptionKey: "Transcription failed: \(errorOutput)"])
                }

                let jsonFile = outputFile.appendingPathExtension("json")

                if !FileManager.default.fileExists(atPath: jsonFile.path) {
                    throw NSError(domain: "WhisperManager", code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Transcription JSON file not found"])
                }

                let jsonData = try Data(contentsOf: jsonFile)
                let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

                var segments: [WhisperTranscriptionSegment] = []

                // Parse segments if available
                if let segmentArray = result?["segments"] as? [[String: Any]] {
                    for segment in segmentArray {
                        if let start = segment["start"] as? Double,
                           let end = segment["end"] as? Double,
                           let text = segment["text"] as? String {
                            let cleanedText = self.cleanTranscriptionText(text)
                            if !cleanedText.isEmpty {
                                segments.append(WhisperTranscriptionSegment(
                                    startTime: start,
                                    endTime: end,
                                    text: cleanedText
                                ))
                            }
                        }
                    }
                } else if let text = result?["text"] as? String {
                    // Fallback: single segment with full text
                    let cleanedText = self.cleanTranscriptionText(text)
                    if !cleanedText.isEmpty {
                        segments.append(WhisperTranscriptionSegment(
                            startTime: 0,
                            endTime: 0,
                            text: cleanedText
                        ))
                    }
                }

                try? FileManager.default.removeItem(at: tempDir)

                DispatchQueue.main.async {
                    completion(.success(segments))
                }
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Clean transcription text by removing unwanted patterns
    private func cleanTranscriptionText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\[.*?\\]|\\(.*?\\)|♪.*?♪", with: "", options: .regularExpression)
            .replacingOccurrences(of: "♪", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - URLSessionDownloadDelegate Methods (kept for compatibility but not used)

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Not used with Lightning Whisper MLX
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Not used with Lightning Whisper MLX
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        // Not used with Lightning Whisper MLX
    }

    func waitUntilReady() async {
        // Wait for up to 10 seconds for the model to be ready
        for _ in 0..<100 {
            if isReady {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
}
