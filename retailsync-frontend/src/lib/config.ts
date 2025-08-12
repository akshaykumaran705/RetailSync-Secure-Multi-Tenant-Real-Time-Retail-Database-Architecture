// Configuration for RetailSync frontend
// This file handles environment-specific configuration

interface Config {
  apiBaseUrl: string;
  environment: string;
}

const config: Config = {
  apiBaseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://your-production-backend-url.com' // Update this with your actual production backend URL
    : 'http://127.0.0.1:5000',
  environment: process.env.NODE_ENV || 'development'
};

export default config; 