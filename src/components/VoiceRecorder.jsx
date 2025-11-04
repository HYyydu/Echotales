import React, { useState, useRef } from "react";
import axios from "axios";
import { ELEVENLABS_API_KEY, ELEVENLABS_API_URL } from "../config/api";
import "./VoiceRecorder.css";

const VoiceRecorder = ({ onVoiceRecorded }) => {
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [recordedAudio, setRecordedAudio] = useState(null);
  const [error, setError] = useState(null);
  const [voiceId, setVoiceId] = useState(null);

  const mediaRecorderRef = useRef(null);
  const audioChunksRef = useRef([]);

  const startRecording = async () => {
    try {
      setError(null);
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(audioChunksRef.current, {
          type: "audio/webm",
        });
        const audioUrl = URL.createObjectURL(audioBlob);
        setRecordedAudio(audioUrl);

        // Process the recording to create a voice clone
        await processVoiceRecording(audioBlob);

        // Stop all tracks
        stream.getTracks().forEach((track) => track.stop());
      };

      mediaRecorder.start();
      setIsRecording(true);
    } catch (err) {
      setError(
        "Microphone access denied. Please allow microphone permissions."
      );
      console.error("Error accessing microphone:", err);
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    }
  };

  const processVoiceRecording = async (audioBlob) => {
    setIsProcessing(true);
    setError(null);

    try {
      // Convert audioBlob to File format for ElevenLabs API
      const audioFile = new File([audioBlob], "recording.webm", {
        type: "audio/webm",
      });

      // Create FormData for ElevenLabs voice cloning API
      const formData = new FormData();
      formData.append("name", "My Voice Clone");
      formData.append("files", audioFile);

      // Call ElevenLabs API to create voice clone
      const response = await axios.post(
        `${ELEVENLABS_API_URL}/voices/add`,
        formData,
        {
          headers: {
            "xi-api-key": ELEVENLABS_API_KEY,
          },
        }
      );

      const voiceId = response.data.voice_id;
      setVoiceId(voiceId);
      onVoiceRecorded(voiceId);
    } catch (err) {
      setError(
        err.response?.data?.detail?.message ||
          "Failed to process voice recording. Please try again."
      );
      console.error("Error processing voice:", err);
    } finally {
      setIsProcessing(false);
    }
  };

  const resetRecording = () => {
    setRecordedAudio(null);
    setVoiceId(null);
    onVoiceRecorded(null);
    setError(null);
  };

  return (
    <div className="voice-recorder">
      <h2>🎤 Record Your Voice</h2>
      <p className="description">
        Record a sample of your voice (at least 30 seconds recommended) to
        create your voice clone.
      </p>

      {error && <div className="error-message">{error}</div>}

      <div className="recording-controls">
        {!isRecording && !recordedAudio && (
          <button
            className="btn btn-primary"
            onClick={startRecording}
            disabled={isProcessing}
          >
            {isProcessing ? "Processing..." : "Start Recording"}
          </button>
        )}

        {isRecording && (
          <button className="btn btn-danger" onClick={stopRecording}>
            ⏹️ Stop Recording
          </button>
        )}

        {recordedAudio && !isProcessing && (
          <div className="recording-complete">
            <audio src={recordedAudio} controls className="audio-player" />
            <div className="voice-status">
              {voiceId ? (
                <div className="success-message">
                  ✅ Voice cloned successfully! Voice ID: {voiceId}
                </div>
              ) : (
                <div className="processing-message">
                  Processing your voice...
                </div>
              )}
            </div>
            <button className="btn btn-secondary" onClick={resetRecording}>
              Record Again
            </button>
          </div>
        )}
      </div>

      {isRecording && (
        <div className="recording-indicator">
          <div className="pulse"></div>
          <span>Recording...</span>
        </div>
      )}
    </div>
  );
};

export default VoiceRecorder;
