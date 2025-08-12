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
    const existingUser = SessionService.getSession();
    if (existingUser) {
      setCurrentUser(existingUser);
    }
    setIsLoading(false);
  }, []);

  const handleLoginSuccess = (user: User) => {
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

  return <AppLayout user={currentUser} onLogout={handleLogout} />;
}