import { useEffect, useState } from 'react';
import axios from 'axios';

interface VideoEvent {
  id: number;
  filename: string;
  timestamp: string;
}

function App() {
  const [events, setEvents] = useState<VideoEvent[]>([]);
  const [selectedVideo, setSelectedVideo] = useState<string | null>(null);

  useEffect(() => {
    fetchEvents();
  }, []);

  const fetchEvents = async () => {
    try {
      const response = await axios.get('http://localhost:3000/api/events');
      setEvents(response.data);
    } catch (error) {
      console.error('Failed to fetch events', error);
    }
  };

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', maxWidth: '1000px', margin: '0 auto', padding: '20px' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h1>Edge Camera Dashboard</h1>
        <button onClick={fetchEvents} style={{ padding: '8px 16px', cursor: 'pointer' }}>Refresh</button>
      </header>

      <div style={{ display: 'flex', gap: '20px' }}>
        <div style={{ flex: '1' }}>
          <h2>Event Log</h2>
          {events.length === 0 ? (
            <p>No events recorded yet.</p>
          ) : (
            <ul style={{ listStyle: 'none', padding: 0 }}>
              {events.map((event) => (
                <li 
                  key={event.id} 
                  style={{ 
                    padding: '12px', 
                    marginBottom: '8px', 
                    border: '1px solid #ccc', 
                    borderRadius: '8px',
                    cursor: 'pointer',
                    backgroundColor: selectedVideo === event.filename ? '#e6f7ff' : '#fff'
                  }}
                  onClick={() => setSelectedVideo(event.filename)}
                >
                  <strong>{new Date(event.timestamp).toLocaleString()}</strong>
                  <br/>
                  <span style={{ fontSize: '0.85em', color: '#666' }}>{event.filename}</span>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div style={{ flex: '2' }}>
          <h2>Playback</h2>
          {selectedVideo ? (
            <div style={{ background: '#000', padding: '10px', borderRadius: '8px' }}>
              <video 
                key={selectedVideo}
                controls 
                autoPlay
                style={{ width: '100%', borderRadius: '4px' }}
              >
                <source src={`http://localhost:3000/videos/${selectedVideo}`} type="video/mp4" />
                Your browser does not support the video tag.
              </video>
              <h3 style={{ color: '#fff', marginTop: '10px', fontSize: '1rem' }}>{selectedVideo}</h3>
            </div>
          ) : (
            <div style={{ background: '#f5f5f5', padding: '40px', textAlign: 'center', borderRadius: '8px', color: '#888' }}>
              Select an event from the log to view the playback.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
