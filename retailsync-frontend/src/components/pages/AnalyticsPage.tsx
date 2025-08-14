import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, Area, AreaChart } from 'recharts';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { TrendingUp, TrendingDown, DollarSign, ShoppingCart, Users, Package, Download, RefreshCw } from 'lucide-react';
import { User, TopProduct, StoreTransaction } from '@/types';
import { useToast } from '@/hooks/use-toast';
import { apiService } from '@/lib/api';

interface AnalyticsPageProps {
  user: User;
}

const PIE_COLORS = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4', '#84CC16'];

interface AnalyticsData {
  topProducts: TopProduct[];
  storeTransactions: StoreTransaction[];
  salesTrends: any[];
  revenueData: any[];
  performanceMetrics: any;
}

export function AnalyticsPage({ user }: AnalyticsPageProps) {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const { toast } = useToast();

  // Debug user role
  console.log('🔍 AnalyticsPage - Received user:', user);
  console.log('🔍 AnalyticsPage - User role:', user.role);
  console.log('🔍 AnalyticsPage - Is admin check:', user.role === 'admin');

  useEffect(() => {
    fetchAnalyticsData();
  }, [user]);

  const fetchAnalyticsData = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      // Use API service instead of hardcoded URLs
      const [topProductsResponse, storeTransactionsResponse] = await Promise.all([
        apiService.getTopProducts(user.role === 'admin' ? undefined : user.store_id),
        apiService.getStoreTransactions()
      ]);

      if (!topProductsResponse.success || !storeTransactionsResponse.success) {
        throw new Error('Failed to fetch analytics data');
      }

      // Mock additional analytics data for demonstration
      const mockSalesTrends = [
        { month: 'Jan', sales: 45000, target: 50000 },
        { month: 'Feb', sales: 52000, target: 50000 },
        { month: 'Mar', sales: 48000, target: 50000 },
        { month: 'Apr', sales: 61000, target: 55000 },
        { month: 'May', sales: 55000, target: 55000 },
        { month: 'Jun', sales: 67000, target: 60000 }
      ];

      const mockRevenueData = [
        { name: 'Q1', revenue: 145000, profit: 45000, expenses: 100000 },
        { name: 'Q2', revenue: 183000, profit: 63000, expenses: 120000 },
        { name: 'Q3', revenue: 165000, profit: 52000, expenses: 113000 },
        { name: 'Q4', revenue: 201000, profit: 78000, expenses: 123000 }
      ];

      setAnalytics({
        topProducts: topProductsResponse.data as TopProduct[],
        storeTransactions: storeTransactionsResponse.data as StoreTransaction[],
        salesTrends: mockSalesTrends,
        revenueData: mockRevenueData,
        performanceMetrics: {
          totalRevenue: 694000,
          growthRate: 15.3,
          customerRetention: 89.2,
          avgOrderValue: 127.50
        }
      });

      if (isRefresh) {
        toast({
          title: "Analytics Updated",
          description: "Latest data has been loaded successfully"
        });
      }
    } catch (error) {
      console.error('Failed to load analytics data:', error);
      toast({
        title: "Error",
        description: "Failed to load analytics data",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        <span className="ml-2 text-muted-foreground">Loading analytics...</span>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-4xl font-bold text-foreground mb-2">Advanced Analytics</h1>
          <p className="text-muted-foreground">
            Comprehensive business insights and performance metrics {user.role === 'manager' ? `for Store ${user.store_id}` : 'across all stores'}
          </p>
        </div>
        <div className="flex gap-3">
          <Button 
            onClick={() => fetchAnalyticsData(true)}
            disabled={refreshing}
            variant="outline"
            className="gap-2 border-border hover:bg-secondary"
          >
            <RefreshCw size={16} className={refreshing ? 'animate-spin' : ''} />
            Refresh
          </Button>
          <Button className="gap-2 bg-gradient-primary hover:opacity-90">
            <Download size={16} />
            Export Report
          </Button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 animate-slide-up">
        <Card className="bg-gradient-card shadow-card border-border relative overflow-hidden group">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-muted-foreground">Total Revenue</p>
                <p className="text-3xl font-bold text-foreground">{formatCurrency(analytics?.performanceMetrics.totalRevenue || 0)}</p>
                <div className="flex items-center gap-1 mt-2">
                  <TrendingUp size={14} className="text-success" />
                  <span className="text-sm text-success font-medium">+15.3%</span>
                </div>
              </div>
              <div className="p-3 rounded-full bg-gradient-to-br from-blue-500 to-cyan-500 group-hover:scale-110 transition-transform">
                <DollarSign size={24} className="text-white" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gradient-card shadow-card border-border relative overflow-hidden group">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-muted-foreground">Growth Rate</p>
                <p className="text-3xl font-bold text-foreground">{analytics?.performanceMetrics.growthRate || 0}%</p>
                <div className="flex items-center gap-1 mt-2">
                  <TrendingUp size={14} className="text-success" />
                  <span className="text-sm text-success font-medium">+2.1%</span>
                </div>
              </div>
              <div className="p-3 rounded-full bg-gradient-to-br from-green-500 to-emerald-500 group-hover:scale-110 transition-transform">
                <TrendingUp size={24} className="text-white" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gradient-card shadow-card border-border relative overflow-hidden group">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-muted-foreground">Customer Retention</p>
                <p className="text-3xl font-bold text-foreground">{analytics?.performanceMetrics.customerRetention || 0}%</p>
                <div className="flex items-center gap-1 mt-2">
                  <TrendingDown size={14} className="text-orange-500" />
                  <span className="text-sm text-orange-500 font-medium">-1.2%</span>
                </div>
              </div>
              <div className="p-3 rounded-full bg-gradient-to-br from-purple-500 to-violet-500 group-hover:scale-110 transition-transform">
                <Users size={24} className="text-white" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gradient-card shadow-card border-border relative overflow-hidden group">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-muted-foreground">Avg Order Value</p>
                <p className="text-3xl font-bold text-foreground">{formatCurrency(analytics?.performanceMetrics.avgOrderValue || 0)}</p>
                <div className="flex items-center gap-1 mt-2">
                  <TrendingUp size={14} className="text-success" />
                  <span className="text-sm text-success font-medium">+8.7%</span>
                </div>
              </div>
              <div className="p-3 rounded-full bg-gradient-to-br from-orange-500 to-red-500 group-hover:scale-110 transition-transform">
                <ShoppingCart size={24} className="text-white" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Analytics Tabs */}
      <Tabs defaultValue="performance" className="animate-slide-up" style={{ animationDelay: '0.1s' }}>
        <TabsList className="grid w-full grid-cols-4 lg:w-fit">
          <TabsTrigger value="performance">Performance</TabsTrigger>
          <TabsTrigger value="products">Products</TabsTrigger>
          <TabsTrigger value="stores">Stores</TabsTrigger>
          <TabsTrigger value="trends">Trends</TabsTrigger>
        </TabsList>

        <TabsContent value="performance" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card className="bg-gradient-card shadow-card border-border">
              <CardHeader>
                <CardTitle className="text-xl font-semibold text-foreground">
                  Sales vs Target
                </CardTitle>
              </CardHeader>
              <CardContent className="h-80">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={analytics?.salesTrends || []}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--chart-grid))" />
                    <XAxis dataKey="month" stroke="hsl(var(--chart-axis))" fontSize={12} />
                    <YAxis stroke="hsl(var(--chart-axis))" fontSize={12} tickFormatter={(value) => `$${(value / 1000).toFixed(0)}k`} />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'hsl(var(--card))', 
                        border: '1px solid hsl(var(--border))',
                        borderRadius: '8px'
                      }}
                      formatter={(value: number) => [`$${value.toLocaleString()}`, '']}
                    />
                    <Legend />
                    <Area type="monotone" dataKey="target" stackId="1" stroke="hsl(var(--muted-foreground))" fill="hsl(var(--muted-foreground))" fillOpacity={0.3} />
                    <Area type="monotone" dataKey="sales" stackId="2" stroke="hsl(var(--primary))" fill="hsl(var(--primary))" fillOpacity={0.6} />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            <Card className="bg-gradient-card shadow-card border-border">
              <CardHeader>
                <CardTitle className="text-xl font-semibold text-foreground">
                  Revenue Breakdown
                </CardTitle>
              </CardHeader>
              <CardContent className="h-80">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={analytics?.revenueData || []}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--chart-grid))" />
                    <XAxis dataKey="name" stroke="hsl(var(--chart-axis))" fontSize={12} />
                    <YAxis stroke="hsl(var(--chart-axis))" fontSize={12} tickFormatter={(value) => `$${(value / 1000).toFixed(0)}k`} />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'hsl(var(--card))', 
                        border: '1px solid hsl(var(--border))',
                        borderRadius: '8px'
                      }}
                      formatter={(value: number) => [`$${value.toLocaleString()}`, '']}
                    />
                    <Legend />
                    <Bar dataKey="revenue" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="profit" fill="hsl(var(--accent))" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="expenses" fill="hsl(var(--destructive))" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="products" className="space-y-6">
          <Card className="bg-gradient-card shadow-card border-border">
            <CardHeader>
              <CardTitle className="text-xl font-semibold text-foreground">
                Top Performing Products {user.role === 'manager' ? `(Store ${user.store_id})` : '(All Stores)'}
              </CardTitle>
            </CardHeader>
            <CardContent className="h-96">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={analytics?.topProducts || []} layout="vertical" margin={{ top: 5, right: 30, left: 100, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--chart-grid))" />
                  <XAxis type="number" stroke="hsl(var(--chart-axis))" fontSize={12} />
                  <YAxis type="category" dataKey="product_name" stroke="hsl(var(--chart-axis))" width={120} fontSize={12} />
                  <Tooltip 
                    contentStyle={{ 
                      backgroundColor: 'hsl(var(--card))', 
                      border: '1px solid hsl(var(--border))',
                      borderRadius: '8px'
                    }}
                    formatter={(value: number) => [value, 'Units Sold']}
                  />
                  <Bar dataKey="total_sold" fill="hsl(var(--primary))" radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="stores" className="space-y-6">
          <Card className="bg-gradient-card shadow-card border-border">
            <CardHeader>
              <CardTitle className="text-xl font-semibold text-foreground">
                Store Performance Distribution
              </CardTitle>
            </CardHeader>
            <CardContent className="h-96">
              {user.role === 'admin' ? (
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={analytics?.storeTransactions || []}
                      dataKey="transaction_count"
                      nameKey="location"
                      cx="50%"
                      cy="50%"
                      outerRadius={120}
                      fill="hsl(var(--primary))"
                      label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                    >
                      {analytics?.storeTransactions.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'hsl(var(--card))', 
                        border: '1px solid hsl(var(--border))',
                        borderRadius: '8px'
                      }}
                      formatter={(value: number) => [value, 'Transactions']}
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              ) : (
                <div className="flex items-center justify-center h-full">
                  <div className="text-center space-y-4">
                    <div className="text-6xl">🔒</div>
                    <div className="space-y-2">
                      <h3 className="text-xl font-semibold text-foreground">Admin Access Required</h3>
                      <p className="text-muted-foreground max-w-sm">
                        Store performance distribution is available to administrators only. Contact your admin for access.
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="trends" className="space-y-6">
          <Card className="bg-gradient-card shadow-card border-border">
            <CardHeader>
              <CardTitle className="text-xl font-semibold text-foreground">
                Sales Trend Analysis
              </CardTitle>
            </CardHeader>
            <CardContent className="h-96">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={analytics?.salesTrends || []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--chart-grid))" />
                  <XAxis dataKey="month" stroke="hsl(var(--chart-axis))" fontSize={12} />
                  <YAxis stroke="hsl(var(--chart-axis))" fontSize={12} tickFormatter={(value) => `$${(value / 1000).toFixed(0)}k`} />
                  <Tooltip 
                    contentStyle={{ 
                      backgroundColor: 'hsl(var(--card))', 
                      border: '1px solid hsl(var(--border))',
                      borderRadius: '8px'
                    }}
                    formatter={(value: number) => [`$${value.toLocaleString()}`, '']}
                  />
                  <Legend />
                  <Line type="monotone" dataKey="sales" stroke="hsl(var(--primary))" strokeWidth={3} activeDot={{ r: 6 }} />
                  <Line type="monotone" dataKey="target" stroke="hsl(var(--muted-foreground))" strokeWidth={2} strokeDasharray="5 5" />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}