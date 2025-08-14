// API service for RetailSync frontend
// This service handles all communication with the backend API

import { User, DashboardData, Product, Customer, Transaction, TransactionDetails } from '@/types';

const API_BASE_URL = 'http://localhost:5002';

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

class ApiService {
  private baseUrl: string;

  constructor() {
    this.baseUrl = API_BASE_URL;
  }

  async login(username: string, password: string): Promise<ApiResponse<User>> {
    try {
      console.log('🔍 ApiService - Login request for username:', username);
      console.log('🔍 ApiService - Login URL:', `${this.baseUrl}/api/login`);
      
      const response = await fetch(`${this.baseUrl}/api/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ username, password }),
      });

      console.log('🔍 ApiService - Login response status:', response.status);
      console.log('🔍 ApiService - Login response headers:', response.headers);
      
      const data = await response.json();
      console.log('🔍 ApiService - Login response data:', data);
      
      if (response.ok) {
        console.log('🔍 ApiService - Login successful, user role:', data.role);
        return { success: true, data };
      } else {
        console.log('🔍 ApiService - Login failed:', data.error);
        return { success: false, error: data.error || 'Login failed' };
      }
    } catch (error) {
      console.error('🔍 ApiService - Login network error:', error);
      return { success: false, error: 'Network error' };
    }
  }

  async getDashboardData(storeId: number): Promise<ApiResponse<DashboardData>> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/stores/${storeId}/dashboard`, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load dashboard data' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getAdminDashboard(): Promise<ApiResponse<any>> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/admin/dashboard`, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load admin dashboard' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getAllStores(): Promise<ApiResponse<any[]>> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/stores`, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data: data.data };
      } else {
        return { success: false, error: data.error || 'Failed to load stores' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getProducts(storeId?: number): Promise<ApiResponse<Product[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/products`;
      if (storeId) {
        url = `${this.baseUrl}/api/v1/stores/${storeId}/products`;
      }
      
      const response = await fetch(url, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load products' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getTopProducts(storeId?: number): Promise<ApiResponse<any[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/analytics/top-products`;
      if (storeId) {
        url += `?store_id=${storeId}`;
      }
      
      console.log('🔍 ApiService - getTopProducts URL:', url);
      console.log('🔍 ApiService - getTopProducts storeId:', storeId);
      
      const response = await fetch(url, {
        credentials: 'include'
      });
      
      console.log('🔍 ApiService - getTopProducts response status:', response.status);
      console.log('🔍 ApiService - getTopProducts response headers:', response.headers);
      
      const data = await response.json();
      console.log('🔍 ApiService - getTopProducts response data:', data);
      
      if (response.ok) {
        console.log('🔍 ApiService - getTopProducts successful');
        return { success: true, data };
      } else {
        console.log('🔍 ApiService - getTopProducts failed:', data.error);
        return { success: false, error: data.error || 'Failed to load top products' };
      }
    } catch (error) {
      console.error('🔍 ApiService - getTopProducts network error:', error);
      return { success: false, error: 'Network error' };
    }
  }

  async getStoreTransactions(storeId?: number): Promise<ApiResponse<any[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/analytics/store-transactions`;
      if (storeId) {
        url += `?store_id=${storeId}`;
      }
      
      console.log('🔍 ApiService - getStoreTransactions URL:', url);
      console.log('🔍 ApiService - getStoreTransactions storeId:', storeId);
      
      const response = await fetch(url, {
        credentials: 'include'
      });
      
      console.log('🔍 ApiService - getStoreTransactions response status:', response.status);
      console.log('🔍 ApiService - getStoreTransactions response headers:', response.headers);
      
      const data = await response.json();
      console.log('🔍 ApiService - getStoreTransactions response data:', data);
      
      if (response.ok) {
        console.log('🔍 ApiService - getStoreTransactions successful');
        return { success: true, data };
      } else {
        console.log('🔍 ApiService - getStoreTransactions failed:', data.error);
        return { success: false, error: data.error || 'Failed to load store transactions' };
      }
    } catch (error) {
      console.error('🔍 ApiService - getStoreTransactions network error:', error);
      return { success: false, error: 'Network error' };
    }
  }

  async getCustomers(storeId?: number): Promise<ApiResponse<Customer[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/customers`;
      if (storeId) {
        url += `?store_id=${storeId}`;
      }
      
      const response = await fetch(url, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load customers' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getTransactions(storeId?: number): Promise<ApiResponse<Transaction[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/transactions`;
      if (storeId) {
        url += `?store_id=${storeId}`;
      }
      
      const response = await fetch(url, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load transactions' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getTransactionDetails(transactionId: number): Promise<ApiResponse<TransactionDetails>> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/transactions/${transactionId}`, {
        credentials: 'include'
      });
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load transaction details' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }
}

export const apiService = new ApiService(); 