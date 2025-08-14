import React, { useState, useEffect } from 'react';
import { Home, BarChart2, ShoppingBag, CreditCard, Users, LogOut, ChevronRight, Clock, Shield } from 'lucide-react';
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { User } from '@/types';
import { SessionService } from '@/lib/session';

interface SidebarProps {
  user: User;
  activePage: string;
  setActivePage: (page: string) => void;
  onLogout: () => void;
}

export function Sidebar({ user, activePage, setActivePage, onLogout }: SidebarProps) {
  const [sessionTimeRemaining, setSessionTimeRemaining] = useState(0);

  useEffect(() => {
    const updateSessionTime = () => {
      const remaining = SessionService.getSessionTimeRemaining();
      setSessionTimeRemaining(remaining);
    };

    // Update session time every minute
    const interval = setInterval(updateSessionTime, 60000);
    updateSessionTime(); // Initial update

    return () => clearInterval(interval);
  }, []);

  const formatSessionTime = (ms: number): string => {
    if (ms <= 0) return 'Expired';
    
    const hours = Math.floor(ms / (1000 * 60 * 60));
    const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const getSessionStatusColor = (ms: number): string => {
    if (ms <= 0) return 'bg-destructive/20 text-destructive border-destructive/30';
    if (ms < 30 * 60 * 1000) return 'bg-yellow-500/20 text-yellow-700 border-yellow-500/30'; // Less than 30 min
    if (ms < 2 * 60 * 60 * 1000) return 'bg-orange-500/20 text-orange-700 border-orange-500/30'; // Less than 2 hours
    return 'bg-green-500/20 text-green-700 border-green-500/30';
  };

  const handleExtendSession = async () => {
    try {
      const success = await SessionService.refreshSession();
      if (success) {
        // Update the session time display
        setSessionTimeRemaining(SessionService.getSessionTimeRemaining());
      } else {
        // Session refresh failed, could trigger logout here
        console.error('Failed to extend session');
      }
    } catch (error) {
      console.error('Failed to extend session:', error);
    }
  };

  const navItems = [
    { name: 'Dashboard', icon: Home, color: 'from-blue-500 to-cyan-500' },
    { name: 'Products', icon: ShoppingBag, color: 'from-green-500 to-emerald-500' },
    { name: 'Transactions', icon: CreditCard, color: 'from-purple-500 to-violet-500' },
    { name: 'Customers', icon: Users, color: 'from-orange-500 to-red-500' },
    { name: 'Analytics', icon: BarChart2, color: 'from-pink-500 to-rose-500' }
  ];

  return (
    <aside className="w-72 bg-gradient-card border-r border-border flex flex-col shadow-elevated animate-fade-in">
      {/* Header */}
      <div className="p-8 border-b border-border/50">
        <div className="relative">
          <h1 className="text-3xl font-bold bg-gradient-primary bg-clip-text text-transparent">
            RetailSync
          </h1>
          <div className="absolute -top-1 -right-1 w-3 h-3 bg-gradient-accent rounded-full animate-glow"></div>
        </div>
        <div className="mt-6 space-y-3">
          <div className="flex items-center justify-between">
            <p className="text-sm font-medium text-foreground">Welcome back,</p>
            <Badge variant="secondary" className="text-xs">
              {user.role.toUpperCase()}
            </Badge>
          </div>
          <p className="text-lg font-semibold text-foreground">User #{user.id}</p>
          {user.store_id && (
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <div className="w-2 h-2 bg-success rounded-full"></div>
              Store ID: {user.store_id}
            </div>
          )}
          
          {/* Session Status */}
          <div className="mt-4 p-3 bg-background/50 rounded-lg border border-border/50">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Shield size={14} />
                <span>Session Status</span>
              </div>
              <Badge className={`text-xs ${getSessionStatusColor(sessionTimeRemaining)}`}>
                {sessionTimeRemaining > 0 ? 'Active' : 'Expired'}
              </Badge>
            </div>
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Clock size={14} />
              <span>Expires in: {formatSessionTime(sessionTimeRemaining)}</span>
            </div>
          </div>
        </div>
      </div>
      
      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-2">
        {navItems.map(({ name, icon: Icon, color }, index) => (
          <div 
            key={name} 
            className="animate-slide-up"
            style={{ animationDelay: `${index * 0.1}s` }}
          >
            <Button
              variant="ghost"
              className={`w-full justify-start gap-4 h-14 group relative overflow-hidden transition-all duration-300 ${
                activePage === name 
                  ? 'bg-primary/10 text-primary border border-primary/20 shadow-lg' 
                  : 'hover:bg-secondary/50 hover:scale-105'
              }`}
              onClick={() => {
                console.log('🖱️ Sidebar - Clicked on:', name);
                setActivePage(name);
              }}
            >
              {/* Icon with gradient background */}
              <div className={`p-2 rounded-lg bg-gradient-to-br ${color} group-hover:scale-110 transition-transform duration-300`}>
                <Icon size={18} className="text-white" />
              </div>
              
              <span className="font-medium flex-1 text-left">{name}</span>
              
              {/* Active indicator */}
              {activePage === name && (
                <ChevronRight size={16} className="text-primary animate-pulse" />
              )}
              
              {/* Hover effect */}
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700"></div>
            </Button>
          </div>
        ))}
      </nav>
      
      {/* Footer */}
      <div className="p-4 border-t border-border/50 space-y-2">
        {/* Session Refresh Button */}
        <Button
          variant="ghost"
          className="w-full justify-start gap-4 h-12 text-primary hover:text-primary hover:bg-primary/10 transition-all duration-300 group"
          onClick={handleExtendSession}
        >
          <div className="p-2 rounded-lg bg-primary/20 group-hover:bg-primary/30 transition-colors">
            <Shield size={16} className="text-primary" />
          </div>
          <span className="font-medium">Extend Session</span>
        </Button>
        
        {/* Logout Button */}
        <Button
          variant="ghost"
          className="w-full justify-start gap-4 h-12 text-destructive hover:text-destructive hover:bg-destructive/10 transition-all duration-300 group"
          onClick={onLogout}
        >
          <div className="p-2 rounded-lg bg-destructive/20 group-hover:bg-destructive/30 transition-colors">
            <LogOut size={16} className="text-destructive" />
          </div>
          <span className="font-medium">Sign Out</span>
        </Button>
      </div>
    </aside>
  );
}