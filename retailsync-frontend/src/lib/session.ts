import { User } from '@/types';

const SESSION_KEY = 'retailsync_session';
const SESSION_EXPIRY_KEY = 'retailsync_session_expiry';

export interface SessionData {
  user: User;
  timestamp: number;
}

export class SessionService {
  // Set session expiry to 24 hours
  private static SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

  static saveSession(user: User): void {
    const sessionData: SessionData = {
      user,
      timestamp: Date.now()
    };
    
    try {
      localStorage.setItem(SESSION_KEY, JSON.stringify(sessionData));
      localStorage.setItem(SESSION_EXPIRY_KEY, (Date.now() + this.SESSION_DURATION).toString());
    } catch (error) {
      console.error('Failed to save session:', error);
    }
  }

  static getSession(): User | null {
    try {
      const sessionData = localStorage.getItem(SESSION_KEY);
      const expiryTime = localStorage.getItem(SESSION_EXPIRY_KEY);
      
      if (!sessionData || !expiryTime) {
        return null;
      }

      const currentTime = Date.now();
      const expiry = parseInt(expiryTime);
      
      // Check if session has expired
      if (currentTime > expiry) {
        this.clearSession();
        return null;
      }

      const session: SessionData = JSON.parse(sessionData);
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

  static refreshSession(): void {
    const user = this.getSession();
    if (user) {
      this.saveSession(user);
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