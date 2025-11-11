const express = require('express');
const axios = require('axios');
const admin = require('firebase-admin');
const cors = require('cors');
const multer = require('multer');
const FormData = require('form-data');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Configure multer for file uploads (voice recordings)
const upload = multer({ 
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// Initialize Firebase Admin
let firebaseInitialized = false;
try {
    const serviceAccount = require('./firebase-service-account.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    firebaseInitialized = true;
    console.log('✅ Firebase Admin initialized successfully');
} catch (error) {
    console.error('⚠️ Firebase Admin initialization failed:', error.message);
    console.log('Note: Some features requiring authentication will not work');
}

// Middleware to verify Firebase token
const verifyFirebaseToken = async (req, res, next) => {
    if (!firebaseInitialized) {
        return res.status(503).json({ error: 'Firebase authentication not available' });
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'No authentication token provided' });
    }

    const token = authHeader.split('Bearer ')[1];
    
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.userId = decodedToken.uid;
        next();
    } catch (error) {
        console.error('Token verification failed:', error.message);
        res.status(401).json({ error: 'Invalid authentication token' });
    }
};

// Simple rate limiting (in-memory, replace with Redis for production)
const userRequestCounts = new Map();
const RATE_LIMIT_WINDOW = 60 * 60 * 1000; // 1 hour
const MAX_REQUESTS_PER_HOUR = 50; // Adjust based on your needs

const checkRateLimit = (userId) => {
    const now = Date.now();
    const userRequests = userRequestCounts.get(userId) || { count: 0, resetTime: now + RATE_LIMIT_WINDOW };
    
    if (now > userRequests.resetTime) {
        // Reset the counter
        userRequestCounts.set(userId, { count: 1, resetTime: now + RATE_LIMIT_WINDOW });
        return { allowed: true, remaining: MAX_REQUESTS_PER_HOUR - 1 };
    }
    
    if (userRequests.count >= MAX_REQUESTS_PER_HOUR) {
        return { allowed: false, remaining: 0, resetTime: userRequests.resetTime };
    }
    
    userRequests.count++;
    userRequestCounts.set(userId, userRequests);
    return { allowed: true, remaining: MAX_REQUESTS_PER_HOUR - userRequests.count };
};

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok',
        firebaseAuth: firebaseInitialized,
        timestamp: new Date().toISOString()
    });
});

// Create voice clone endpoint
app.post('/api/voice-clone', verifyFirebaseToken, upload.single('audio'), async (req, res) => {
    try {
        // Rate limiting
        const rateLimit = checkRateLimit(req.userId);
        if (!rateLimit.allowed) {
            return res.status(429).json({ 
                error: 'Rate limit exceeded',
                resetTime: new Date(rateLimit.resetTime).toISOString()
            });
        }

        const { name } = req.body;
        const audioFile = req.file;

        if (!audioFile) {
            return res.status(400).json({ error: 'No audio file provided' });
        }

        if (!name) {
            return res.status(400).json({ error: 'Voice name is required' });
        }

        console.log(`🎤 Creating voice clone for user ${req.userId}: ${name}`);

        // Create form data for ElevenLabs API
        const formData = new FormData();
        formData.append('name', name);
        formData.append('files', audioFile.buffer, {
            filename: 'recording.m4a',
            contentType: audioFile.mimetype
        });

        // Call ElevenLabs API
        const response = await axios.post(
            `${process.env.ELEVENLABS_BASE_URL}/voices/add`,
            formData,
            {
                headers: {
                    'xi-api-key': process.env.ELEVENLABS_API_KEY,
                    ...formData.getHeaders()
                }
            }
        );

        console.log(`✅ Voice clone created: ${response.data.voice_id}`);

        // Log usage (you can expand this to save to Firestore)
        logUsage(req.userId, 'voice-clone', response.data.voice_id);

        res.json({
            voiceId: response.data.voice_id,
            message: 'Voice clone created successfully',
            remaining: rateLimit.remaining
        });

    } catch (error) {
        console.error('❌ Voice clone error:', error.response?.data || error.message);
        
        // Parse ElevenLabs error response
        let errorMessage = 'Failed to create voice clone';
        let statusCode = 500;
        
        if (error.response?.data) {
            const errorData = error.response.data;
            
            // Check if it's a Buffer and convert to string
            const errorStr = Buffer.isBuffer(errorData) ? errorData.toString('utf-8') : JSON.stringify(errorData);
            console.log('📋 Parsed error:', errorStr);
            
            try {
                const errorJson = JSON.parse(errorStr);
                
                // Handle quota exceeded
                if (errorJson.detail?.status === 'quota_exceeded') {
                    errorMessage = errorJson.detail?.message || 'Voice slots exceeded. Please upgrade your plan.';
                    statusCode = 429;
                }
                // Handle other errors
                else if (errorJson.detail?.message) {
                    errorMessage = errorJson.detail.message;
                }
            } catch (parseError) {
                // If parsing fails, use the error string as-is
                if (errorStr.includes('quota_exceeded')) {
                    errorMessage = 'Voice slots exceeded. Please upgrade your ElevenLabs plan.';
                    statusCode = 429;
                }
            }
        }
        
        // Status code based errors
        if (error.response?.status === 401) {
            errorMessage = 'API authentication failed. Please contact support.';
            statusCode = 500;
        } else if (error.response?.status === 429) {
            errorMessage = 'API rate limit exceeded. Please try again later.';
            statusCode = 429;
        }
        
        res.status(statusCode).json({ error: errorMessage });
    }
});

// Text-to-speech endpoint
app.post('/api/text-to-speech', verifyFirebaseToken, async (req, res) => {
    try {
        // Rate limiting
        const rateLimit = checkRateLimit(req.userId);
        if (!rateLimit.allowed) {
            return res.status(429).json({ 
                error: 'Rate limit exceeded',
                resetTime: new Date(rateLimit.resetTime).toISOString()
            });
        }

        const { voiceId, text, modelId = 'eleven_monolingual_v1' } = req.body;

        if (!voiceId || !text) {
            return res.status(400).json({ error: 'voiceId and text are required' });
        }

        console.log(`🗣️ Generating speech for user ${req.userId}, voice: ${voiceId}, length: ${text.length} chars`);

        // Call ElevenLabs API
        const response = await axios.post(
            `${process.env.ELEVENLABS_BASE_URL}/text-to-speech/${voiceId}`,
            {
                text: text,
                model_id: modelId,
                voice_settings: {
                    stability: 0.5,
                    similarity_boost: 0.75
                }
            },
            {
                headers: {
                    'xi-api-key': process.env.ELEVENLABS_API_KEY,
                    'Content-Type': 'application/json'
                },
                responseType: 'arraybuffer',
                timeout: 120000 // 2 minutes
            }
        );

        console.log(`✅ Speech generated: ${response.data.length} bytes`);

        // Log usage
        logUsage(req.userId, 'text-to-speech', voiceId, text.length);

        // Send audio back to client
        res.set({
            'Content-Type': 'audio/mpeg',
            'Content-Length': response.data.length,
            'X-Rate-Limit-Remaining': rateLimit.remaining
        });
        res.send(Buffer.from(response.data));

    } catch (error) {
        console.error('❌ Text-to-speech error:', error.response?.data || error.message);
        
        // Parse ElevenLabs error response
        let errorMessage = 'Failed to generate speech';
        let statusCode = 500;
        
        if (error.response?.data) {
            const errorData = error.response.data;
            
            // Check if it's a Buffer and convert to string
            const errorStr = Buffer.isBuffer(errorData) ? errorData.toString('utf-8') : JSON.stringify(errorData);
            console.log('📋 Parsed error:', errorStr);
            
            try {
                const errorJson = JSON.parse(errorStr);
                
                // Handle quota exceeded
                if (errorJson.detail?.status === 'quota_exceeded') {
                    errorMessage = errorJson.detail?.message || 'Character quota exceeded. Please upgrade your plan.';
                    statusCode = 429;
                }
                // Handle other errors
                else if (errorJson.detail?.message) {
                    errorMessage = errorJson.detail.message;
                }
            } catch (parseError) {
                // If parsing fails, use the error string as-is
                if (errorStr.includes('quota_exceeded')) {
                    errorMessage = 'Character quota exceeded. Please upgrade your ElevenLabs plan.';
                    statusCode = 429;
                }
            }
        }
        
        // Status code based errors
        if (error.response?.status === 401) {
            errorMessage = 'API authentication failed. Please contact support.';
            statusCode = 500;
        } else if (error.response?.status === 429) {
            errorMessage = 'API rate limit exceeded. Please try again later.';
            statusCode = 429;
        }
        
        res.status(statusCode).json({ error: errorMessage });
    }
});

// Usage logging function (expand to save to Firestore)
function logUsage(userId, action, details, charCount) {
    const timestamp = new Date().toISOString();
    console.log(`📊 Usage: ${timestamp} | User: ${userId} | Action: ${action} | Details: ${details || 'N/A'} | Chars: ${charCount || 'N/A'}`);
    
    // TODO: Save to Firestore for persistent tracking
    // const db = admin.firestore();
    // await db.collection('usage_logs').add({
    //     userId,
    //     action,
    //     details,
    //     charCount,
    //     timestamp: admin.firestore.FieldValue.serverTimestamp()
    // });
}

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(port, () => {
    console.log(`🚀 Echotales backend server running on port ${port}`);
    console.log(`📍 Health check: http://localhost:${port}/health`);
    console.log(`🔐 Firebase Auth: ${firebaseInitialized ? 'Enabled' : 'Disabled'}`);
});

