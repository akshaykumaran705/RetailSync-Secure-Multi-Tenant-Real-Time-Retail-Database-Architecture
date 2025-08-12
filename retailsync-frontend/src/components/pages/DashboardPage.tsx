import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { KpiCard } from '@/components/ui/kpi-card';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { StoreSelector } from '@/components/StoreSelector';
import { User, DashboardData } from '@/types';
import { apiService } from '@/lib/api';

interface DashboardPageProps {
  user: User;
}

export function DashboardPage({ user }: DashboardPageProps) {
  const [data, setData] = useState<DashboardData | null>(null);
  const [adminData, setAdminData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedStoreId, setSelectedStoreId] = useState<number | null>(null);

  useEffect(() => {
    // For admin users, default to null (all stores), for managers use their store_id
    if (user.role === 'admin') {
      setSelectedStoreId(null);
      loadAdminDashboard();
    } else {
      setSelectedStoreId(user.store_id);
      loadDashboardData(user.store_id);
    }
  }, [user]);

  useEffect(() => {
    if (selectedStoreId !== null) {
      loadDashboardData(selectedStoreId);
    }
  }, [selectedStoreId]);

  const loadDashboardData = async (storeId: number) => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await apiService.getDashboardData(storeId);
      
      if (response.success && response.data) {
        setData(response.data as DashboardData);
      } else {
        setError(response.error || 'Failed to load dashboard data');
      }
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const loadAdminDashboard = async () => {
    try {
      console.log('🔄 Loading admin dashboard...');
      setLoading(true);
      setError(null);
      
      const response = await apiService.getAdminDashboard();
      console.log('📊 Admin dashboard response:', response);
      
      if (response.success && response.data) {
        setAdminData(response.data);
        console.log('✅ Admin data set successfully:', response.data);
      } else {
        console.error('❌ Admin dashboard failed:', response.error);
        setError(response.error || 'Failed to load admin dashboard');
      }
    } catch (err) {
      console.error('💥 Admin dashboard error:', err);
      setError('Failed to load admin dashboard');
    } finally {
      setLoading(false);
    }
  };

  const handleStoreSelect = (storeId: number | null) => {
    setSelectedStoreId(storeId);
    if (storeId === null) {
      // Load admin dashboard for all stores
      loadAdminDashboard();
    } else {
      // Load specific store dashboard
      loadDashboardData(storeId);
    }
  };

  // Show loading state for admin users when adminData is not yet loaded
  if (user.role === 'admin' && selectedStoreId === null && !adminData && loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-muted-foreground">Loading Admin Dashboard...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-destructive">
          {error || 'Failed to load dashboard data'}
        </div>
      </div>
    );
  }

  // Render Admin Dashboard (All stores)
  if (user.role === 'admin' && selectedStoreId === null) {
    // Add loading state for admin data
    if (!adminData) {
      return (
        <div className="flex items-center justify-center h-64">
          <div className="text-muted-foreground">Loading Admin Dashboard...</div>
        </div>
      );
    }

    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground mb-2">Admin Dashboard</h1>
          <p className="text-muted-foreground">
            Overview of all stores and performance metrics
          </p>
        </div>

        <StoreSelector 
          user={user} 
          selectedStoreId={selectedStoreId} 
          onStoreSelect={handleStoreSelect} 
        />

        {/* Admin Summary Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <KpiCard 
            title="Total Stores" 
            value={adminData.data.totals.store_count.toString()}
          />
          <KpiCard 
            title="Total Sales" 
            value={`$${adminData.data.totals.total_sales.toLocaleString()}`}
          />
          <KpiCard 
            title="Total Transactions" 
            value={adminData.data.totals.total_transactions.toLocaleString()}
          />
          <KpiCard 
            title="Total Products" 
            value={adminData.data.totals.total_products.toLocaleString()}
          />
        </div>

        {/* Stores Summary Table */}
        <Card className="bg-gradient-card shadow-card border-border">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-foreground">
              Store Performance Summary
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Store</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Location</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Transactions</th>
                    <th className="text-left py-4 px-4 font-medium text-muted-foreground">Sales</th>
                    <th className="text-left py-4 px-4 font-medium text-muted-foreground">Products</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {adminData.data.stores_summary.map((store: any) => (
                    <tr key={store.store_id} className="hover:bg-secondary/50 transition-colors">
                      <td className="py-4 px-4 font-medium text-foreground">
                        Store {store.store_id}
                      </td>
                      <td className="py-4 px-4 text-foreground">
                        {store.location}
                      </td>
                      <td className="py-4 px-4 text-foreground">
                        {store.transaction_count.toLocaleString()}
                      </td>
                      <td className="py-4 px-4 font-mono text-foreground">
                        ${store.total_sales.toLocaleString()}
                      </td>
                      <td className="py-4 px-4 text-foreground">
                        {store.product_count.toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Render Store-specific Dashboard
  if (data) {
    const calculateTrend = () => {
      const current = data.kpi_summary.current_weekly_sales;
      const previous = data.kpi_summary.previous_weekly_sales;
      return current > previous ? 'up' : current < previous ? 'down' : 'neutral';
    };

    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground mb-2">Dashboard</h1>
          <p className="text-muted-foreground">
            Overview for Store ID: {data.store_id} ({data.store_location})
          </p>
        </div>

        {/* Store Selector for Admins */}
        {user.role === 'admin' && (
          <StoreSelector 
            user={user} 
            selectedStoreId={selectedStoreId} 
            onStoreSelect={handleStoreSelect} 
          />
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <KpiCard 
            title="Current Weekly Sales" 
            value={`$${data.kpi_summary.current_weekly_sales.toLocaleString()}`}
            trend={calculateTrend()}
          />
          <KpiCard 
            title="Previous Weekly Sales" 
            value={`$${data.kpi_summary.previous_weekly_sales.toLocaleString()}`}
          />
          <KpiCard 
            title="Holiday Week" 
            value={data.kpi_summary.is_holiday_week ? "Yes" : "No"}
          />
        </div>

        <Card className="bg-gradient-card shadow-card border-border">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-foreground">
              7-Day Sales Trend
            </CardTitle>
          </CardHeader>
          <CardContent className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data.sales_trend_7_days}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip formatter={(value) => [`$${value}`, 'Sales']} />
                <Legend />
                <Line 
                  type="monotone" 
                  dataKey="sales" 
                  stroke="#3b82f6" 
                  strokeWidth={2}
                  dot={{ fill: '#3b82f6', strokeWidth: 2, r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>
    );
  }

  return null;
}