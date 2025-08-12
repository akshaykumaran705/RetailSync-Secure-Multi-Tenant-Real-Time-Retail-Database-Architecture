import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Search, Filter, Calendar, DollarSign, ShoppingBag, Download, Eye } from 'lucide-react';
import { User, Transaction } from '@/types';
import { useToast } from '@/hooks/use-toast';
import { apiService } from '@/lib/api';
import { StoreSelector } from '@/components/StoreSelector';

interface TransactionsPageProps {
  user: User;
}

export function TransactionsPage({ user }: TransactionsPageProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filteredTransactions, setFilteredTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedStoreId, setSelectedStoreId] = useState<number | null>(null);
  const [filters, setFilters] = useState({
    search: '',
    dateFrom: '',
    dateTo: '',
    minAmount: '',
    maxAmount: ''
  });
  const { toast } = useToast();

  useEffect(() => {
    // For admin users, default to null (all stores), for managers use their store_id
    if (user.role === 'admin') {
      setSelectedStoreId(null);
      fetchTransactions();
    } else {
      setSelectedStoreId(user.store_id);
      fetchTransactions(user.store_id);
    }
  }, [user]);

  useEffect(() => {
    if (selectedStoreId !== null || user.role === 'admin') {
      fetchTransactions(selectedStoreId || undefined);
    }
  }, [selectedStoreId]);

  useEffect(() => {
    applyFilters();
  }, [transactions, filters]);

  const fetchTransactions = async (storeId?: number) => {
    try {
      setLoading(true);
      console.log('🔍 Fetching transactions...', { storeId });
      
      const response = await apiService.getTransactions(storeId);
      
      console.log('📡 API Response:', response);
      
      if (response.success && response.data) {
        console.log('✅ Transactions data received:', response.data);
        setTransactions(response.data as Transaction[]);
      } else {
        console.error('❌ API Error:', response.error);
        throw new Error(response.error || 'Failed to fetch transactions');
      }
    } catch (error) {
      console.error('❌ Failed to load transactions:', error);
      toast({
        title: "Error",
        description: "Failed to load transaction data",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const applyFilters = () => {
    let filtered = [...transactions];

    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(t => 
        t.transaction_id.toString().includes(searchLower) ||
        t.store_location.toLowerCase().includes(searchLower) ||
        t.payment_method.toLowerCase().includes(searchLower) ||
        t.customer_id?.toString().includes(searchLower)
      );
    }

    if (filters.dateFrom) {
      filtered = filtered.filter(t => new Date(t.transaction_date) >= new Date(filters.dateFrom));
    }
    if (filters.dateTo) {
      filtered = filtered.filter(t => new Date(t.transaction_date) <= new Date(filters.dateTo));
    }

    if (filters.minAmount) {
      const minAmount = parseFloat(filters.minAmount);
      filtered = filtered.filter(t => t.total_amount >= minAmount);
    }
    if (filters.maxAmount) {
      const maxAmount = parseFloat(filters.maxAmount);
      filtered = filtered.filter(t => t.total_amount <= maxAmount);
    }

    setFilteredTransactions(filtered);
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
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const handleStoreSelect = (storeId: number | null) => {
    setSelectedStoreId(storeId);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        <span className="ml-2 text-muted-foreground">Loading transactions...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-4xl font-bold text-foreground mb-2">Transaction Management</h1>
          <p className="text-muted-foreground">
            Monitor and analyze transaction data {user.role === 'manager' ? `for Store ${user.store_id}` : 'across all stores'}
          </p>
        </div>
        <Button className="gap-2 bg-gradient-primary hover:opacity-90">
          <Download size={16} />
          Export Transactions
        </Button>
      </div>

      {/* Store Selector for Admins */}
      {user.role === 'admin' && (
        <StoreSelector 
          user={user} 
          selectedStoreId={selectedStoreId} 
          onStoreSelect={handleStoreSelect} 
        />
      )}

      {/* Filters */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <Filter size={20} />
            Transaction Filters
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search transactions..."
                value={filters.search}
                onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                className="pl-10 bg-background border-border"
              />
            </div>
            
            <Input
              type="date"
              placeholder="Date from"
              value={filters.dateFrom}
              onChange={(e) => setFilters(prev => ({ ...prev, dateFrom: e.target.value }))}
              className="bg-background border-border"
            />
            
            <Input
              type="date"
              placeholder="Date to"
              value={filters.dateTo}
              onChange={(e) => setFilters(prev => ({ ...prev, dateTo: e.target.value }))}
              className="bg-background border-border"
            />

            <Input
              type="number"
              placeholder="Min amount ($)"
              value={filters.minAmount}
              onChange={(e) => setFilters(prev => ({ ...prev, minAmount: e.target.value }))}
              className="bg-background border-border"
            />

            <Button 
              onClick={() => setFilters({ search: '', dateFrom: '', dateTo: '', minAmount: '', maxAmount: '' })}
              variant="outline"
              className="border-border hover:bg-secondary"
            >
              Clear Filters
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Results Summary */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <ShoppingBag size={20} />
            Transaction Summary
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">{filteredTransactions.length}</div>
              <div className="text-sm text-muted-foreground">Total Transactions</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">
                {formatCurrency(filteredTransactions.reduce((sum, t) => sum + t.total_amount, 0))}
              </div>
              <div className="text-sm text-muted-foreground">Total Amount</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">
                {filteredTransactions.length > 0 ? formatCurrency(filteredTransactions.reduce((sum, t) => sum + t.total_amount, 0) / filteredTransactions.length) : 'N/A'}
              </div>
              <div className="text-sm text-muted-foreground">Average Amount</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">
                {filteredTransactions.reduce((sum, t) => sum + t.items_count, 0)}
              </div>
              <div className="text-sm text-muted-foreground">Total Items</div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Transactions Table */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <Calendar size={20} />
            Transaction List
          </CardTitle>
        </CardHeader>
        <CardContent>
          {filteredTransactions.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Transaction</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Store</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Date</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Customer</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Payment</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Amount</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Items</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {filteredTransactions.map((transaction) => (
                    <tr key={transaction.transaction_id} className="hover:bg-secondary/50 transition-colors">
                      <td className="py-4 px-4">
                        <div className="font-medium text-foreground">#{transaction.transaction_id}</div>
                      </td>
                      <td className="py-4 px-4">
                        <Badge variant="secondary" className="bg-blue-500/20 text-blue-700 border-blue-500/30">
                          Store {transaction.store_id}
                        </Badge>
                        <div className="text-sm text-muted-foreground mt-1">
                          {transaction.store_location}
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        <div className="text-sm text-foreground">
                          {formatDate(transaction.transaction_date)}
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        {transaction.customer_id ? (
                          <div className="text-sm text-foreground">
                            Customer #{transaction.customer_id}
                          </div>
                        ) : (
                          <span className="text-sm text-muted-foreground">Guest</span>
                        )}
                      </td>
                      <td className="py-4 px-4">
                        <Badge variant="outline" className="border-border">
                          {transaction.payment_method}
                        </Badge>
                      </td>
                      <td className="py-4 px-4">
                        <div className="font-mono font-medium text-foreground">
                          {formatCurrency(transaction.total_amount)}
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        <div className="flex items-center gap-2">
                          <ShoppingBag size={16} className="text-muted-foreground" />
                          <span className="text-sm text-foreground">
                            {transaction.items_count}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12">
              <Calendar size={48} className="mx-auto text-muted-foreground mb-4" />
              <p className="text-lg text-muted-foreground mb-4">No transactions found</p>
              <Button
                onClick={() => setFilters({ search: '', dateFrom: '', dateTo: '', minAmount: '', maxAmount: '' })}
                variant="outline"
                className="border-border hover:bg-secondary"
              >
                Clear Filters
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}