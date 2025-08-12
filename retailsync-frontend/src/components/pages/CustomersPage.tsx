import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Search, Filter, Mail, Phone, Calendar, ShoppingBag, Download, Eye } from 'lucide-react';
import { User, Customer, FilterOptions } from '@/types';
import { useToast } from '@/hooks/use-toast';
import { apiService } from '@/lib/api';

interface CustomersPageProps {
  user: User;
}

export function CustomersPage({ user }: CustomersPageProps) {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [filteredCustomers, setFilteredCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<FilterOptions>({
    search: '',
    dateFrom: '',
    dateTo: '',
    minAmount: undefined,
    maxAmount: undefined
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchCustomers();
  }, [user]);

  useEffect(() => {
    applyFilters();
  }, [customers, filters]);

  const fetchCustomers = async () => {
    try {
      setLoading(true);
      console.log('🔍 Fetching customers...');
      
      const response = await apiService.getCustomers(
        user.role === 'admin' ? undefined : user.store_id
      );
      
      console.log('📡 API Response:', response);
      
      if (response.success && response.data) {
        console.log('✅ Customers data received:', response.data);
        setCustomers(response.data as Customer[]);
      } else {
        console.error('❌ API Error:', response.error);
        throw new Error(response.error || 'Failed to fetch customers');
      }
    } catch (error) {
      console.error('❌ Failed to load customers:', error);
      toast({
        title: "Error",
        description: "Failed to load customer data",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const applyFilters = () => {
    let filtered = [...customers];

    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(c => 
        c.gender.toLowerCase().includes(searchLower) ||
        c.loyalty_level.toLowerCase().includes(searchLower) ||
        c.age.toString().includes(filters.search) ||
        c.income.toString().includes(filters.search)
      );
    }

    if (filters.dateFrom) {
      filtered = filtered.filter(c => c.last_order_date && new Date(c.last_order_date) >= new Date(filters.dateFrom!));
    }
    if (filters.dateTo) {
      filtered = filtered.filter(c => c.last_order_date && new Date(c.last_order_date) <= new Date(filters.dateTo!));
    }

    if (filters.minAmount) {
      filtered = filtered.filter(c => c.total_spent >= filters.minAmount!);
    }
    if (filters.maxAmount) {
      filtered = filtered.filter(c => c.total_spent <= filters.maxAmount!);
    }

    setFilteredCustomers(filtered);
  };

  const getCustomerTier = (totalSpent: number) => {
    if (totalSpent >= 5000) return { tier: 'VIP', color: 'bg-yellow-500/20 text-yellow-700 border-yellow-500/30' };
    if (totalSpent >= 2000) return { tier: 'Gold', color: 'bg-orange-500/20 text-orange-700 border-orange-500/30' };
    if (totalSpent >= 500) return { tier: 'Silver', color: 'bg-gray-500/20 text-gray-700 border-gray-500/30' };
    return { tier: 'Bronze', color: 'bg-amber-500/20 text-amber-700 border-amber-500/30' };
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
  };

  const getInitials = (gender: string, age: number) => {
    return `${gender[0]}${age}`.toUpperCase();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        <span className="ml-2 text-muted-foreground">Loading customers...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-4xl font-bold text-foreground mb-2">Customer Management</h1>
          <p className="text-muted-foreground">
            Manage customer relationships and analyze spending patterns {user.role === 'manager' ? `for Store ${user.store_id}` : 'across all stores'}
          </p>
        </div>
        <Button className="gap-2 bg-gradient-primary hover:opacity-90">
          <Download size={16} />
          Export Customers
        </Button>
      </div>

      {/* Filters */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <Filter size={20} />
            Customer Filters
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search customers..."
                value={filters.search}
                onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                className="pl-10 bg-background border-border"
              />
            </div>
            
            <Input
              type="date"
              placeholder="Join date from"
              value={filters.dateFrom}
              onChange={(e) => setFilters(prev => ({ ...prev, dateFrom: e.target.value }))}
              className="bg-background border-border"
            />
            
            <Input
              type="date"
              placeholder="Join date to"
              value={filters.dateTo}
              onChange={(e) => setFilters(prev => ({ ...prev, dateTo: e.target.value }))}
              className="bg-background border-border"
            />

            <Input
              type="number"
              placeholder="Min spent ($)"
              value={filters.minAmount || ''}
              onChange={(e) => setFilters(prev => ({ ...prev, minAmount: e.target.value ? parseFloat(e.target.value) : undefined }))}
              className="bg-background border-border"
            />

            <Button 
              onClick={() => setFilters({ search: '', dateFrom: '', dateTo: '', minAmount: undefined, maxAmount: undefined })}
              variant="outline"
              className="border-border hover:bg-secondary"
            >
              Clear Filters
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Results Summary */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 animate-slide-up" style={{ animationDelay: '0.1s' }}>
        <Card className="bg-gradient-card shadow-card border-border">
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-foreground">{filteredCustomers.length}</div>
            <div className="text-sm text-muted-foreground">Total Customers</div>
          </CardContent>
        </Card>
        <Card className="bg-gradient-card shadow-card border-border">
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-foreground">
              {formatCurrency(filteredCustomers.reduce((sum, c) => sum + c.total_spent, 0))}
            </div>
            <div className="text-sm text-muted-foreground">Total Spent</div>
          </CardContent>
        </Card>
        <Card className="bg-gradient-card shadow-card border-border">
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-foreground">
              {filteredCustomers.length > 0 ? Math.round(filteredCustomers.reduce((sum, c) => sum + c.total_spent, 0) / filteredCustomers.length) : 0}
            </div>
            <div className="text-sm text-muted-foreground">Avg. Spent</div>
          </CardContent>
        </Card>
        <Card className="bg-gradient-card shadow-card border-border">
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-foreground">
              {filteredCustomers.reduce((sum, c) => sum + c.orders_count, 0)}
            </div>
            <div className="text-sm text-muted-foreground">Total Orders</div>
          </CardContent>
        </Card>
      </div>

      {/* Customers Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 animate-slide-up" style={{ animationDelay: '0.2s' }}>
        {filteredCustomers.map((customer, index) => {
          const tierInfo = getCustomerTier(customer.total_spent);
          
          return (
            <Card 
              key={customer.customer_id} 
              className="bg-gradient-card shadow-card border-border hover:shadow-elevated transition-all duration-300 hover:scale-105 animate-scale-in group"
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <CardContent className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <Avatar className="h-12 w-12 border-2 border-primary/20">
                      <AvatarFallback className="bg-gradient-primary text-white font-semibold">
                        {getInitials(customer.gender, customer.age)}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <h3 className="font-semibold text-foreground">
                        Customer #{customer.customer_id}
                      </h3>
                      <p className="text-sm text-muted-foreground">
                        {customer.age} years old, {customer.gender}
                      </p>
                    </div>
                  </div>
                  <Badge className={`${tierInfo.color} font-medium`}>
                    {tierInfo.tier}
                  </Badge>
                </div>

                <div className="space-y-3">
                  <div className="flex items-center gap-2 text-sm">
                    <div className="text-muted-foreground font-medium">Income:</div>
                    <span className="text-foreground">{formatCurrency(customer.income)}</span>
                  </div>
                  
                  <div className="flex items-center gap-2 text-sm">
                    <div className="text-muted-foreground font-medium">Loyalty:</div>
                    <span className="text-foreground">{customer.loyalty_level}</span>
                  </div>
                  
                  <div className="flex items-center gap-2 text-sm">
                    <Calendar size={14} className="text-muted-foreground" />
                    <span className="text-foreground">
                      {customer.last_order_date ? `Last order: ${formatDate(customer.last_order_date)}` : 'No orders yet'}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4 mt-4 pt-4 border-t border-border/50">
                  <div className="text-center">
                    <div className="text-lg font-bold text-foreground">{formatCurrency(customer.total_spent)}</div>
                    <div className="text-xs text-muted-foreground">Total Spent</div>
                  </div>
                  <div className="text-center">
                    <div className="text-lg font-bold text-foreground">{customer.orders_count}</div>
                    <div className="text-xs text-muted-foreground">Orders</div>
                  </div>
                </div>

                <div className="flex gap-2 mt-4">
                  <Button 
                    size="sm" 
                    variant="outline" 
                    className="flex-1 gap-1 border-border hover:bg-secondary group-hover:border-primary/50"
                  >
                    <Eye size={14} />
                    View Profile
                  </Button>
                  <Button 
                    size="sm" 
                    variant="outline" 
                    className="flex-1 gap-1 border-border hover:bg-secondary group-hover:border-primary/50"
                  >
                    <ShoppingBag size={14} />
                    Orders
                  </Button>
                </div>

                {customer.last_order_date && (
                  <div className="mt-3 pt-3 border-t border-border/50">
                    <p className="text-xs text-muted-foreground">
                      Last order: {formatDate(customer.last_order_date)}
                    </p>
                  </div>
                )}
              </CardContent>
            </Card>
          );
        })}
      </div>

      {filteredCustomers.length === 0 && (
        <Card className="bg-gradient-card shadow-card border-border">
          <CardContent className="text-center py-12">
            <div className="text-6xl mb-4">👥</div>
            <h3 className="text-xl font-semibold text-foreground mb-2">No customers found</h3>
            <p className="text-muted-foreground">Try adjusting your search filters</p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}