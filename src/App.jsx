import React, { useState } from "react";
import VoiceRecorder from "./components/VoiceRecorder";
import BookReader from "./components/BookReader";
import "./App.css";

function App() {
  const [recordedVoiceId, setRecordedVoiceId] = useState(null);

  return (
    <div className="app">
      <header className="app-header">
        <h1>📚 Echotales</h1>
        <p>Record your voice and listen to stories read in your own voice</p>
      </header>

      <div className="app-content">
        <VoiceRecorder onVoiceRecorded={setRecordedVoiceId} />
        <BookReader voiceId={recordedVoiceId} />
      </div>
    </div>
  );
}

export default App;
