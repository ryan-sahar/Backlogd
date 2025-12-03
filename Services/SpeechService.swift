//
//  SpeechService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Service layer for speech recognition using SFSpeechRecognizer.
//  Handles permissions and voice-to-text conversion.
//

import Foundation
import Combine
import Speech
import AVFoundation

/// Errors that can occur during speech recognition.
enum SpeechServiceError: Error, LocalizedError {
    case permissionDenied
    case recognitionUnavailable
    case audioSessionError
    case recognitionFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice search."
        case .recognitionUnavailable:
            return "Speech recognition is not available on this device."
        case .audioSessionError:
            return "Could not set up audio session."
        case .recognitionFailed:
            return "Speech recognition failed. Please try again."
        case .invalidFormat:
            return "Audio format is invalid. Please try again."
        }
    }
}

/// Service responsible for speech recognition operations.
final class SpeechService: NSObject, ObservableObject {
    
    static let shared = SpeechService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var currentCompletion: ((Result<String, Error>) -> Void)?
    private var latestTranscription: String = ""
    private var timeoutTimer: Timer?
    private var hasCompleted: Bool = false
    
    @Published var isRecording = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    /// Checks the current authorization status for speech recognition.
    func checkAuthorizationStatus() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    /// Requests authorization for speech recognition.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                completion(status == .authorized)
            }
        }
    }
    
    /// Starts speech recognition and returns transcribed text via completion handler.
    ///
    /// - Parameter completion: Called with the transcribed text or an error.
    func startRecording(completion: @escaping (Result<String, Error>) -> Void) {
        // Store the completion handler so we can use it when manually stopping
        currentCompletion = completion
        latestTranscription = ""
        hasCompleted = false
        // Check authorization
        guard authorizationStatus == .authorized else {
            if authorizationStatus == .notDetermined {
                requestAuthorization { [weak self] authorized in
                    if authorized {
                        self?.startRecording(completion: completion)
                    } else {
                        completion(.failure(SpeechServiceError.permissionDenied))
                    }
                }
                return
            } else {
                completion(.failure(SpeechServiceError.permissionDenied))
                return
            }
        }
        
        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(.failure(SpeechServiceError.recognitionUnavailable))
            return
        }
        
        // Stop any existing recognition and completely clean up
        stopRecording()
        
        // Create a fresh audio engine to avoid any state issues
        audioEngine = AVAudioEngine()
        
        // Set up audio session FIRST - this is critical
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(.failure(SpeechServiceError.audioSessionError))
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(SpeechServiceError.recognitionFailed))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get the input node - must be done after audio session is active
        let inputNode = audioEngine.inputNode
        
        // Get the format from the input node - should be valid once session is active
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate the format has valid properties
        guard recordingFormat.sampleRate > 0,
              recordingFormat.channelCount > 0 else {
            try? audioSession.setActive(false)
            completion(.failure(SpeechServiceError.invalidFormat))
            return
        }
        
        // Install tap BEFORE preparing - this is the correct order
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let request = self.recognitionRequest else { return }
            request.append(buffer)
        }
        
        // Prepare the engine after installing the tap
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            inputNode.removeTap(onBus: 0)
            try? audioSession.setActive(false)
            completion(.failure(SpeechServiceError.audioSessionError))
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                
                // Store the latest transcription (even if not final)
                DispatchQueue.main.async {
                    self.latestTranscription = transcribedText
                }
                
                // If this is the final result, stop and return
                if result.isFinal {
                    DispatchQueue.main.async {
                        guard !self.hasCompleted else { return }
                        self.hasCompleted = true
                        self.stopRecording()
                        if let completion = self.currentCompletion {
                            self.currentCompletion = nil
                            completion(.success(transcribedText))
                        }
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    guard !self.hasCompleted else { return }
                    self.hasCompleted = true
                    self.stopRecording()
                    if let completion = self.currentCompletion {
                        self.currentCompletion = nil
                        completion(.failure(error))
                    }
                }
            }
        }
        
        // Set up a timeout to automatically stop after 5 seconds of inactivity
        // This matches industry standards (Google: ~5s, Siri: ~5s, Alexa: ~5s)
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.stopRecordingWithResult()
            }
        }
    }
    
    /// Stops recording and returns the latest transcribed text (or error if none).
    private func stopRecordingWithResult() {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        let text = latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let completion = currentCompletion {
            currentCompletion = nil
            if text.isEmpty {
                completion(.failure(SpeechServiceError.recognitionFailed))
            } else {
                completion(.success(text))
            }
        }
        
        stopRecording()
    }
    
    /// Stops speech recognition and cleans up resources.
    /// If called manually, will return the latest transcribed text.
    func stopRecording() {
        // Cancel timeout timer
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        // End audio request before cancelling task to get any pending results
        recognitionRequest?.endAudio()
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Stop and clean up audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap if it exists
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    /// Stops recording manually and returns whatever text was recognized.
    func stopRecordingManually() {
        // Prevent duplicate completion calls
        guard !hasCompleted else { return }
        
        // End the audio request first to signal we're done
        // This allows the recognition task to process any final audio
        recognitionRequest?.endAudio()
        
        // Wait a brief moment for any final transcription to come through
        // Then return whatever we have
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.hasCompleted else { return }
            self.hasCompleted = true
            
            // If we have a completion handler, call it with the latest transcription
            if let completion = self.currentCompletion {
                let text = self.latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                self.currentCompletion = nil
                
                if text.isEmpty {
                    completion(.failure(SpeechServiceError.recognitionFailed))
                } else {
                    completion(.success(text))
                }
            }
            
            self.stopRecording()
        }
    }
}
