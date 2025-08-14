import { User } from '@/types';

const SESSION_KEY = 'retailsync_session';
const SESSION_EXPIRY_KEY = 'retailsync_session_expiry';
const API_BASE_URL = 'http://localhost:5002';

export interface SessionData {
  user: User;
  timestamp: number;
}

export class SessionService {
  // Set session expiry to 24 hours
  private static SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

  static async checkBackendSession(): Promise<User | null> {
    try {
      console.log('🔍 SessionService - Checking backend session...');
      const response = await fetch(`${API_BASE_URL}/api/session`, {
        credentials: 'include'
      });
      
      console.log('🔍 SessionService - Backend session response status:', response.status);
      console.log('🔍 SessionService - Backend session response headers:', response.headers);
      
      if (response.ok) {
        const data = await response.json();
        console.log('🔍 SessionService - Backend session data:', data);
        if (data.authenticated && data.user) {
          // Update local storage with backend session data
          console.log('🔍 SessionService - Backend session authenticated, user:', data.user);
          this.saveSession(data.user);
          return data.user;
        }
      }
      
      // If backend session is invalid, clear local session
      console.log('🔍 SessionService - Backend session invalid, clearing local session');
      this.clearSession();
      return null;
    } catch (error) {
      console.error('Failed to check backend session:', error);
      return null;
    }
  }

  static saveSession(user: User): void {
    console.log('🔍 SessionService - Saving session for user:', user);
    console.log('🔍 SessionService - User role:', user.role);
    
    const sessionData: SessionData = {
      user,
      timestamp: Date.now()
    };
    
    try {
      localStorage.setItem(SESSION_KEY, JSON.stringify(sessionData));
      localStorage.setItem(SESSION_EXPIRY_KEY, (Date.now() + this.SESSION_DURATION).toString());
      console.log('🔍 SessionService - Session saved successfully');
    } catch (error) {
      console.error('Failed to save session:', error);
    }
  }

  static getSession(): User | null {
    try {
      console.log('🔍 SessionService - Getting session from localStorage...');
      const sessionData = localStorage.getItem(SESSION_KEY);
      const expiryTime = localStorage.getItem(SESSION_EXPIRY_KEY);
      
      console.log('🔍 SessionService - Session data from localStorage:', sessionData);
      console.log('🔍 SessionService - Expiry time from localStorage:', expiryTime);
      
      if (!sessionData || !expiryTime) {
        console.log('🔍 SessionService - No session data or expiry time found');
        return null;
      }

      const currentTime = Date.now();
      const expiry = parseInt(expiryTime);
      
      console.log('🔍 SessionService - Current time:', currentTime);
      console.log('🔍 SessionService - Expiry time:', expiry);
      
      // Check if session has expired
      if (currentTime > expiry) {
        console.log('🔍 SessionService - Session expired, clearing session');
        this.clearSession();
        return null;
      }

      const session: SessionData = JSON.parse(sessionData);
      console.log('🔍 SessionService - Retrieved session:', session);
      console.log('🔍 SessionService - User from session:', session.user);
      console.log('🔍 SessionService - User role from session:', session.user.role);
      
      return session.user;
    } catch (error) {
      console.error('Failed to retrieve session:', error);
      this.clearSession();
      return null;
    }
  }

  static clearSession(): void {
    try {
      localStorage.removeItem(SESSION_KEY);
      localStorage.removeItem(SESSION_EXPIRY_KEY);
    } catch (error) {
      console.error('Failed to clear session:', error);
    }
  }

  static isSessionValid(): boolean {
    const user = this.getSession();
    return user !== null;
  }

  static async refreshSession(): Promise<boolean> {
    try {
      const user = await this.checkBackendSession();
      return user !== null;
    } catch (error) {
      console.error('Failed to refresh session:', error);
      return false;
    }
  }

  static getSessionTimeRemaining(): number {
    try {
      const expiryTime = localStorage.getItem(SESSION_EXPIRY_KEY);
      if (!expiryTime) return 0;
      
      const currentTime = Date.now();
      const expiry = parseInt(expiryTime);
      return Math.max(0, expiry - currentTime);
    } catch (error) {
      return 0;
    }
  }
} 