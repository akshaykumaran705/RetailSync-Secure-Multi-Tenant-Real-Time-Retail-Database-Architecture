import React, { useState } from 'react';
import { Sidebar } from './Sidebar';
import { DashboardPage } from '@/components/pages/DashboardPage';
import { ProductsPage } from '@/components/pages/ProductsPage';
import { TransactionsPage } from '@/components/pages/TransactionsPage';
import { CustomersPage } from '@/components/pages/CustomersPage';
import { AnalyticsPage } from '@/components/pages/AnalyticsPage';
import { SessionManager } from '@/components/SessionManager';
import { User } from '@/types';

// Test if components are imported correctly
console.log('🔧 AppLayout - ProductsPage component:', ProductsPage);
console.log('🔧 AppLayout - DashboardPage component:', DashboardPage);

interface AppLayoutProps {
  user: User;
  onLogout: () => void;
}

export function AppLayout({ user, onLogout }: AppLayoutProps) {
  const [activePage, setActivePage] = useState('Dashboard');

  // Debug user role
  console.log('🔍 AppLayout - Received user:', user);
  console.log('🔍 AppLayout - User role:', user.role);

  const renderPage = () => {
    console.log('🎯 AppLayout - Rendering page:', activePage);
    console.log('🎯 AppLayout - User role in renderPage:', user.role);
    
    switch (activePage) {
      case 'Dashboard':
        return <DashboardPage user={user} />;
      case 'Products':
        console.log('🛍️ AppLayout - Rendering ProductsPage');
        return <ProductsPage user={user} />;
      case 'Transactions':
        return <TransactionsPage user={user} />;
      case 'Customers':
        return <CustomersPage user={user} />;
      case 'Analytics':
        return <AnalyticsPage user={user} />;
      default:
        console.log('⚠️ AppLayout - Unknown page, defaulting to Dashboard');
        return <DashboardPage user={user} />;
    }
  };

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar 
        user={user} 
        activePage={activePage} 
        setActivePage={setActivePage} 
        onLogout={onLogout} 
      />
      <main className="flex-1 p-8 overflow-auto bg-gradient-to-br from-background via-background to-secondary/10">
        <div className="max-w-7xl mx-auto">
          {renderPage()}
        </div>
      </main>
      
      {/* Session Management */}
      <SessionManager onSessionExpired={onLogout} />
    </div>
  );
}