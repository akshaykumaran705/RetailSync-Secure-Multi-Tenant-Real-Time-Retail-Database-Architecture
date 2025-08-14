import React, { useState, useEffect } from 'react';
import { LoginScreen } from './auth/LoginScreen';
import { AppLayout } from './layout/AppLayout';
import { User } from '@/types';
import { SessionService } from '@/lib/session';

export default function RetailSyncApp() {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check for existing session on component mount
    const checkSession = async () => {
      try {
        // First check local storage
        const existingUser = SessionService.getSession();
        console.log('🔍 RetailSyncApp - Existing user from session:', existingUser);
        if (existingUser) {
          // Then verify with backend
          const backendUser = await SessionService.checkBackendSession();
          console.log('🔍 RetailSyncApp - Backend user:', backendUser);
          if (backendUser) {
            console.log('🔍 RetailSyncApp - Setting current user:', backendUser);
            setCurrentUser(backendUser);
          } else {
            // Backend session invalid, clear local session
            console.log('🔍 RetailSyncApp - Backend session invalid, clearing session');
            SessionService.clearSession();
            setCurrentUser(null);
          }
        }
      } catch (error) {
        console.error('Session check failed:', error);
        SessionService.clearSession();
        setCurrentUser(null);
      } finally {
        setIsLoading(false);
      }
    };

    checkSession();
  }, []);

  const handleLoginSuccess = (user: User) => {
    console.log('🔍 RetailSyncApp - Login success, user:', user);
    console.log('🔍 RetailSyncApp - User role:', user.role);
    setCurrentUser(user);
    SessionService.saveSession(user);
  };

  const handleLogout = () => {
    setCurrentUser(null);
    SessionService.clearSession();
  };

  // Show loading state while checking session
  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  if (!currentUser) {
    return <LoginScreen onLoginSuccess={handleLoginSuccess} />;
  }

  console.log('🔍 RetailSyncApp - Rendering AppLayout with user:', currentUser);
  console.log('🔍 RetailSyncApp - User role in render:', currentUser.role);
  
  return <AppLayout user={currentUser} onLogout={handleLogout} />;
}