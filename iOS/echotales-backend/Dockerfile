# Use Node.js 18 (long-term support)
FROM node:18-slim

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy application files
COPY server.js ./
COPY firebase-service-account.json ./

# Cloud Run will automatically set the PORT environment variable
# Default to 8080 if not set (for local testing)
EXPOSE 8080

# Start the server
CMD ["node", "server.js"]

