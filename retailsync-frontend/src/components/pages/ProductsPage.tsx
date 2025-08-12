import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Search, Filter, Package, TrendingUp, DollarSign, AlertTriangle, Download } from 'lucide-react';
import { User, Product } from '@/types';
import { apiService } from '@/lib/api';

interface ProductsPageProps {
  user: User;
}

export function ProductsPage({ user }: ProductsPageProps) {
  console.log('🚀 ProductsPage component rendered!', { user });
  
  const [products, setProducts] = useState<Product[]>([]);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState({
    search: '',
    category: '',
    minPrice: '',
    maxPrice: '',
    stockStatus: '',
    minStock: '',
    maxStock: ''
  });

  useEffect(() => {
    const loadProducts = async () => {
      try {
        setLoading(true);
        setError(null);
        console.log('🔍 Fetching products...');
        
        // For admin users, don't pass store_id to see all products
        const storeId = user.role === 'admin' ? undefined : user.store_id;
        console.log('🎯 Store ID to fetch:', storeId);
        
        const response = await apiService.getProducts(storeId);
        console.log('📡 API Response:', response);
        
        if (response.success && response.data) {
          if (Array.isArray(response.data)) {
            setProducts(response.data);
            setFilteredProducts(response.data);
            console.log('✅ Products loaded:', response.data.length);
          } else {
            setError('Invalid data format received');
          }
        } else {
          setError(response.error || 'Failed to load products');
        }
      } catch (err) {
        console.error('❌ Error loading products:', err);
        setError(`Failed to load products: ${err instanceof Error ? err.message : 'Unknown error'}`);
      } finally {
        setLoading(false);
      }
    };

    loadProducts();
  }, [user]);

  // Apply filters whenever filters or products change
  useEffect(() => {
    let filtered = [...products];

    // Search filter
    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(product =>
        product.product_name.toLowerCase().includes(searchLower) ||
        product.category_name.toLowerCase().includes(searchLower)
      );
    }

    // Category filter
    if (filters.category) {
      filtered = filtered.filter(product => product.category_name === filters.category);
    }

    // Price range filter
    if (filters.minPrice) {
      const minPrice = parseFloat(filters.minPrice);
      filtered = filtered.filter(product => product.unit_price >= minPrice);
    }
    if (filters.maxPrice) {
      const maxPrice = parseFloat(filters.maxPrice);
      filtered = filtered.filter(product => product.unit_price <= maxPrice);
    }

    // Stock status filter
    if (filters.stockStatus) {
      switch (filters.stockStatus) {
        case 'in_stock':
          filtered = filtered.filter(product => product.inventory_level > 0);
          break;
        case 'out_of_stock':
          filtered = filtered.filter(product => product.inventory_level === 0);
          break;
        case 'low_stock':
          filtered = filtered.filter(product => product.inventory_level > 0 && product.inventory_level <= 10);
          break;
      }
    }

    // Stock level range filter
    if (filters.minStock) {
      const minStock = parseInt(filters.minStock);
      filtered = filtered.filter(product => product.inventory_level >= minStock);
    }
    if (filters.maxStock) {
      const maxStock = parseInt(filters.maxStock);
      filtered = filtered.filter(product => product.inventory_level <= maxStock);
    }

    setFilteredProducts(filtered);
  }, [filters, products]);

  const getUniqueCategories = () => {
    const categories = [...new Set(products.map(p => p.category_name))];
    return categories.sort();
  };

  const clearFilters = () => {
    setFilters({
      search: '',
      category: '',
      minPrice: '',
      maxPrice: '',
      stockStatus: '',
      minStock: '',
      maxStock: ''
    });
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  const getStockStatus = (inventoryLevel: number) => {
    if (inventoryLevel === 0) {
      return { status: 'Out of Stock', color: 'bg-red-500/20 text-red-700 border-red-500/30' };
    } else if (inventoryLevel <= 10) {
      return { status: 'Low Stock', color: 'bg-yellow-500/20 text-yellow-700 border-yellow-500/30' };
    } else {
      return { status: 'In Stock', color: 'bg-green-500/20 text-green-700 border-green-500/30' };
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        <span className="ml-2 text-muted-foreground">Loading products...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-destructive text-center">
          <p className="text-lg font-semibold mb-2">Error Loading Products</p>
          <p>{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-4xl font-bold text-foreground mb-2">Product Management</h1>
          <p className="text-muted-foreground">
            Manage inventory and analyze product performance {user.role === 'manager' ? `for Store ${user.store_id}` : 'across all stores'}
          </p>
        </div>
        <Button className="gap-2 bg-gradient-primary hover:opacity-90">
          <Download size={16} />
          Export Products
        </Button>
      </div>

      {/* Advanced Filters */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <Filter size={20} />
            Product Filters
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Search */}
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search products..."
                value={filters.search}
                onChange={(e) => setFilters({...filters, search: e.target.value})}
                className="pl-10 bg-background border-border"
              />
            </div>

            {/* Category */}
            <select
              value={filters.category}
              onChange={(e) => setFilters({...filters, category: e.target.value})}
              className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="">All Categories</option>
              {getUniqueCategories().map(category => (
                <option key={category} value={category}>{category}</option>
              ))}
            </select>

            {/* Price Range */}
            <Input
              type="number"
              placeholder="Min Price ($)"
              step="0.01"
              value={filters.minPrice}
              onChange={(e) => setFilters({...filters, minPrice: e.target.value})}
              className="bg-background border-border"
            />

            <Input
              type="number"
              placeholder="Max Price ($)"
              step="0.01"
              value={filters.maxPrice}
              onChange={(e) => setFilters({...filters, maxPrice: e.target.value})}
              className="bg-background border-border"
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Stock Status */}
            <select
              value={filters.stockStatus}
              onChange={(e) => setFilters({...filters, stockStatus: e.target.value})}
              className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="">All Stock Status</option>
              <option value="in_stock">In Stock</option>
              <option value="out_of_stock">Out of Stock</option>
              <option value="low_stock">Low Stock (≤10)</option>
            </select>

            {/* Stock Level Range */}
            <Input
              type="number"
              placeholder="Min Stock"
              min="0"
              value={filters.minStock}
              onChange={(e) => setFilters({...filters, minStock: e.target.value})}
              className="bg-background border-border"
            />

            <Input
              type="number"
              placeholder="Max Stock"
              min="0"
              value={filters.maxStock}
              onChange={(e) => setFilters({...filters, maxStock: e.target.value})}
              className="bg-background border-border"
            />
          </div>

          {/* Filter Actions */}
          <div className="flex justify-between items-center">
            <Button 
              onClick={clearFilters}
              variant="outline"
              className="border-border hover:bg-secondary"
            >
              Clear All Filters
            </Button>
            
            <div className="text-sm text-muted-foreground">
              Showing {filteredProducts.length} of {products.length} products
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Results Summary */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <TrendingUp size={20} />
            Inventory Summary
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">{filteredProducts.length}</div>
              <div className="text-sm text-muted-foreground">Total Products</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">
                {formatCurrency(filteredProducts.reduce((sum, p) => sum + (p.unit_price * p.inventory_level), 0))}
              </div>
              <div className="text-sm text-muted-foreground">Total Value</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">
                {filteredProducts.length > 0 ? formatCurrency(filteredProducts.reduce((sum, p) => sum + p.unit_price, 0) / filteredProducts.length) : '$0.00'}
              </div>
              <div className="text-sm text-muted-foreground">Average Price</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-foreground">{getUniqueCategories().length}</div>
              <div className="text-sm text-muted-foreground">Categories</div>
            </div>
          </div>
        </CardContent>
      </Card>
      
      {/* Products Table */}
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <Package size={20} />
            Product Inventory
          </CardTitle>
        </CardHeader>
        <CardContent>
          {filteredProducts.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Product</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Category</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Price</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Stock</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Value</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {filteredProducts.map((product) => {
                    const stockInfo = getStockStatus(product.inventory_level);
                    return (
                      <tr key={product.product_id} className="hover:bg-secondary/50 transition-colors">
                        <td className="py-4 px-4">
                          <div>
                            <div className="font-medium text-foreground">{product.product_name}</div>
                            <div className="text-sm text-muted-foreground">ID: {product.product_id}</div>
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <Badge variant="secondary" className="bg-blue-500/20 text-blue-700 border-blue-500/30">
                            {product.category_name}
                          </Badge>
                        </td>
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <DollarSign size={16} className="text-green-600" />
                            <span className="font-mono font-medium text-foreground">
                              {formatCurrency(product.unit_price)}
                            </span>
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <Badge className={stockInfo.color}>
                              {product.inventory_level}
                            </Badge>
                            <span className="text-sm text-muted-foreground">
                              {stockInfo.status}
                            </span>
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <div className="font-mono font-medium text-foreground">
                            {formatCurrency(product.unit_price * product.inventory_level)}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12">
              <Package size={48} className="mx-auto text-muted-foreground mb-4" />
              <p className="text-lg text-muted-foreground mb-4">No products match your current filters</p>
              <Button
                onClick={clearFilters}
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