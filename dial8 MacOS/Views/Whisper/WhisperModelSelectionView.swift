import SwiftUI

struct WhisperModelSelectionView: View {
    @ObservedObject var whisperManager = WhisperManager.shared
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("enableTranscriptionCleaning") private var enableTranscriptionCleaning = true
    @AppStorage("enableAutoPunctuation") private var enableAutoPunctuation = true
    @AppStorage("pauseDetectionThreshold") private var pauseDetectionThreshold: Double = 1.5
    var showTitle: Bool = true
    var showDescription: Bool = true
    var compact: Bool = false
    
    // Add language selection state
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "auto"
    
    // Add tone selection state
    @AppStorage("selectedTone") private var selectedTone: String = "professional"
    
    // Define tone categories
    struct ToneCategory {
        let name: String
        let tones: [(name: String, code: String)]
    }
    
    private let toneCategories = [
        ToneCategory(name: "Standard", tones: [
            ("Professional", "professional"),
            ("Friendly", "friendly"),
            ("Casual", "casual"),
            ("Concise", "concise")
        ]),
        ToneCategory(name: "Generational", tones: [
            ("Gen Z", "genz"),
            ("Millennial", "millennial"),
            ("Boomer", "boomer"),
            ("Internet Culture", "internet")
        ]),
        ToneCategory(name: "Professional", tones: [
            ("Tech Bro", "techbro"),
            ("Academic", "academic"),
            ("Sports Commentator", "sports"),
            ("News Anchor", "news"),
            ("Motivational Speaker", "motivational")
        ]),
        ToneCategory(name: "Creative", tones: [
            ("Shakespearean", "shakespeare"),
            ("Noir Detective", "noir"),
            ("Fantasy/Medieval", "fantasy"),
            ("Sci-Fi", "scifi"),
            ("Pirate", "pirate")
        ]),
        ToneCategory(name: "Mood", tones: [
            ("Passive Aggressive", "passive"),
            ("Overly Dramatic", "dramatic"),
            ("Sarcastic", "sarcastic"),
            ("Wholesome", "wholesome"),
            ("Conspiracy Theorist", "conspiracy")
        ]),
        ToneCategory(name: "Regional", tones: [
            ("Southern Charm", "southern"),
            ("British Posh", "british"),
            ("Surfer Dude", "surfer"),
            ("New York Hustle", "newyork")
        ]),
        ToneCategory(name: "Unique", tones: [
            ("Corporate Email", "corporate"),
            ("Mom Text", "mom"),
            ("Fortune Cookie", "fortune"),
            ("Infomercial", "infomercial"),
            ("Robot/AI", "robot")
        ])
    ]
    
    // Computed property to get all tones as a flat list
    private var allTones: [(name: String, code: String)] {
        toneCategories.flatMap { $0.tones }
    }
    
    // Define supported languages with Whisper's language codes
    private let supportedLanguages: [(name: String, code: String)] = [
        ("English", "en"),
        ("Chinese", "zh"),
        ("German", "de"),
        ("Spanish", "es"),
        ("Russian", "ru"),
        ("Korean", "ko"),
        ("French", "fr"),
        ("Japanese", "ja"),
        ("Portuguese", "pt"),
        ("Turkish", "tr"),
        ("Polish", "pl"),
        ("Italian", "it"),
        ("Vietnamese", "vi"),
        ("Dutch", "nl"),
        ("Persian", "fa"),
        ("Arabic", "ar"),
        ("Auto", "auto")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showTitle {
                Text("Model Settings")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                    // Voice Control Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Model Management Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("Speech to Text Model")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                // Lightning Whisper MLX badge
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 10))
                                    Text("Lightning Whisper MLX")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                            }

                            // Model Selection Dropdown
                            HStack {
                                Text("Select Model")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("Model", selection: $whisperManager.selectedModelSize) {
                                    ForEach(whisperManager.availableModels, id: \.id) { model in
                                        Text(model.displayInfo.displayName)
                                            .tag(model.id)
                                    }
                                }
                                .frame(width: 200)
                                .onChange(of: whisperManager.selectedModelSize) { newValue in
                                    whisperManager.selectModel(modelSize: newValue)
                                }
                            }

                            // Show warning if lightning-whisper-mlx is not installed
                            if !whisperManager.isReady {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Lightning Whisper MLX is not installed")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text("Run: pip install lightning-whisper-mlx")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                            } else {
                                // Ready indicator
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                    Text("Lightning Whisper MLX is ready. Models are downloaded automatically on first use.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }

                            // Model List
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(whisperManager.availableModels, id: \.id) { model in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: model.displayInfo.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(model.id == whisperManager.selectedModelSize ? .blue : .secondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 8) {
                                                    Text(model.displayInfo.displayName)
                                                        .font(.subheadline)
                                                        .fontWeight(model.id == whisperManager.selectedModelSize ? .semibold : .medium)

                                                    if model.id == whisperManager.selectedModelSize {
                                                        Text("Selected")
                                                            .font(.caption2)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.blue.opacity(0.2))
                                                            .foregroundColor(.blue)
                                                            .cornerRadius(4)
                                                    }
                                                }

                                                Text(model.displayInfo.description)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            if model.id != whisperManager.selectedModelSize {
                                                Button(action: {
                                                    whisperManager.selectModel(modelSize: model.id)
                                                }) {
                                                    Text("Select")
                                                        .font(.caption)
                                                }
                                                .buttonStyle(.borderless)
                                                .foregroundColor(.blue)
                                            }
                                        }

                                        if let recommendation = model.displayInfo.recommendation {
                                            Text(recommendation)
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                                .italic()
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(model.id == whisperManager.selectedModelSize ? Color.blue.opacity(0.05) : Color.clear)
                                    .cornerRadius(6)

                                    if model.id != whisperManager.availableModels.last?.id {
                                        Divider()
                                    }
                                }
                            }

                            if let errorMessage = whisperManager.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        Divider()
                        
                        // Language Selection
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("Recognition Language")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("Language", selection: $selectedLanguage) {
                                    ForEach(supportedLanguages, id: \.code) { language in
                                        Text(language.name)
                                            .tag(language.code)
                                    }
                                }
                                .frame(width: 150)
                                .onChange(of: selectedLanguage) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "selectedLanguage")
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("SelectedLanguageChanged"),
                                        object: nil,
                                        userInfo: ["language": newValue]
                                    )
                                }
                            }
                            
                            Text("Select the primary language you'll be speaking in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Transcription Mode and Settings
                        VStack(alignment: .leading, spacing: 12) {
                            // Mode Selection
                            HStack(spacing: 8) {
                                Image(systemName: audioManager.isStreamingMode ? "waveform.badge.plus" : "square.stack.3d.up")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("Transcription Mode")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Text(audioManager.isStreamingMode ? "Stream" : "Block")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Toggle("", isOn: Binding(
                                        get: { audioManager.isStreamingMode },
                                        set: { _ in audioManager.toggleTranscriptionMode() }
                                    ))
                                    .toggleStyle(SwitchToggleStyle())
                                    .scaleEffect(0.8)
                                }
                            }
                            
                            Text(audioManager.isStreamingMode ? 
                                 "Text appears in real-time as you speak" : 
                                 "Text is accumulated during recording and processed simultaneously when you finish, then inserted as a single chunk")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Pause Detection Duration (only show in streaming mode)
                            if audioManager.isStreamingMode {
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                    Text("Pause Detection")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    
                                    Picker("", selection: $pauseDetectionThreshold) {
                                        Text("0.5 seconds").tag(0.5)
                                        Text("0.75 seconds").tag(0.75)
                                        Text("1 second").tag(1.0)
                                        Text("1.25 seconds").tag(1.25)
                                        Text("1.5 seconds").tag(1.5)
                                        Text("1.75 seconds").tag(1.75)
                                        Text("2 seconds").tag(2.0)
                                        Text("2.25 seconds").tag(2.25)
                                        Text("2.5 seconds").tag(2.5)
                                        Text("2.75 seconds").tag(2.75)
                                        Text("3 seconds").tag(3.0)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 120)
                                    .onChange(of: pauseDetectionThreshold) { newValue in
                                        // Notify the speech recognizer of the change
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("PauseDetectionThresholdChanged"),
                                            object: nil,
                                            userInfo: ["threshold": newValue]
                                        )
                                    }
                                }
                                
                                Text("Longer pauses provide better accuracy. Shorter segments may reduce quality.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }
                        }
                        
                        Divider()
                        
                        // AI Rewrite Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("AI Rewrite")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Toggle("", isOn: $enableTranscriptionCleaning)
                                    .toggleStyle(SwitchToggleStyle())
                                    .scaleEffect(0.8)
                            }
                            
                            if enableTranscriptionCleaning {
                                Text("Uses Apple Intelligence to improve grammar and sentence structure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Tone Selection
                                HStack(spacing: 8) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                    Text("Writing Tone")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Picker("Tone", selection: $selectedTone) {
                                        ForEach(toneCategories, id: \.name) { category in
                                            Section(header: Text(category.name)) {
                                                ForEach(category.tones, id: \.code) { tone in
                                                    Text(tone.name)
                                                        .tag(tone.code)
                                                }
                                            }
                                        }
                                    }
                                    .frame(width: 200)
                                    .onChange(of: selectedTone) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "selectedTone")
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("SelectedToneChanged"),
                                            object: nil,
                                            userInfo: ["tone": newValue]
                                        )
                                    }
                                }
                                .padding(.top, 8)
                                
                                Text("Choose how AI rewrites your transcriptions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Auto-Punctuation Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "text.justify.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("Auto-Punctuation")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Toggle("", isOn: $enableAutoPunctuation)
                                    .toggleStyle(SwitchToggleStyle())
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Automatically adds a period at the end of your transcriptions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
            
        }
    }
}
