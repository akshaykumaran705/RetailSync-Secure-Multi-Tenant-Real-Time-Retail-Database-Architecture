import React, { useEffect, useState } from 'react';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { AlertTriangle, Clock, RefreshCw } from 'lucide-react';
import { SessionService } from '@/lib/session';

interface SessionManagerProps {
  onSessionExpired: () => void;
}

export function SessionManager({ onSessionExpired }: SessionManagerProps) {
  const [showWarning, setShowWarning] = useState(false);
  const [timeRemaining, setTimeRemaining] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    const checkSession = () => {
      const remaining = SessionService.getSessionTimeRemaining();
      setTimeRemaining(remaining);

      // Show warning when less than 5 minutes remaining
      if (remaining > 0 && remaining < 5 * 60 * 1000) {
        setShowWarning(true);
      } else {
        setShowWarning(false);
      }

      // Auto-logout when session expires
      if (remaining <= 0) {
        onSessionExpired();
      }
    };

    // Check session every minute
    const interval = setInterval(checkSession, 60000);
    
    // Initial check
    checkSession();

    return () => clearInterval(interval);
  }, [onSessionExpired]);

  const handleRefreshSession = async () => {
    setIsRefreshing(true);
    try {
      const success = await SessionService.refreshSession();
      if (success) {
        setShowWarning(false);
        // Update time remaining
        setTimeRemaining(SessionService.getSessionTimeRemaining());
      } else {
        // Session refresh failed, trigger logout
        onSessionExpired();
      }
    } catch (error) {
      console.error('Failed to refresh session:', error);
      // Session refresh failed, trigger logout
      onSessionExpired();
    } finally {
      setIsRefreshing(false);
    }
  };

  const formatTimeRemaining = (ms: number): string => {
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  if (!showWarning) return null;

  return (
    <div className="fixed top-4 right-4 z-50 animate-slide-up">
      <Card className="w-80 bg-gradient-card shadow-elevated border-border">
        <CardHeader className="pb-3">
          <CardTitle className="flex items-center gap-2 text-foreground text-lg">
            <AlertTriangle size={20} className="text-yellow-500" />
            Session Expiring Soon
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-2 text-muted-foreground">
            <Clock size={16} />
            <span>Your session will expire in:</span>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-foreground font-mono">
              {formatTimeRemaining(timeRemaining)}
            </div>
          </div>

          <div className="flex gap-2">
            <Button
              onClick={handleRefreshSession}
              disabled={isRefreshing}
              className="flex-1 bg-gradient-primary hover:opacity-90"
            >
              {isRefreshing ? (
                <>
                  <RefreshCw size={16} className="animate-spin mr-2" />
                  Refreshing...
                </>
              ) : (
                <>
                  <RefreshCw size={16} className="mr-2" />
                  Extend Session
                </>
              )}
            </Button>
          </div>

          <p className="text-xs text-muted-foreground text-center">
            Click "Extend Session" to stay logged in for another 24 hours
          </p>
        </CardContent>
      </Card>
    </div>
  );
} 