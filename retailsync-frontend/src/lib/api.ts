// API service for RetailSync frontend
// This service handles all communication with the backend API

import { User, DashboardData, Product, Customer, Transaction, TransactionDetails } from '@/types';

const API_BASE_URL = 'http://127.0.0.1:5002';

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
      const response = await fetch(`${this.baseUrl}/api/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password }),
      });

      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Login failed' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getDashboardData(storeId: number): Promise<ApiResponse<DashboardData>> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/stores/${storeId}/dashboard`);
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
      const response = await fetch(`${this.baseUrl}/api/v1/admin/dashboard`);
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
      const response = await fetch(`${this.baseUrl}/api/v1/stores`);
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
      
      const response = await fetch(url);
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
      
      const response = await fetch(url);
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load top products' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getStoreTransactions(storeId?: number): Promise<ApiResponse<any[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/analytics/store-transactions`;
      if (storeId) {
        url += `?store_id=${storeId}`;
      }
      
      const response = await fetch(url);
      const data = await response.json();
      
      if (response.ok) {
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to load store transactions' };
      }
    } catch (error) {
      return { success: false, error: 'Network error' };
    }
  }

  async getCustomers(storeId?: number): Promise<ApiResponse<Customer[]>> {
    try {
      let url = `${this.baseUrl}/api/v1/customers`;
      if (storeId) {
        url += `?store_id=${storeId}`;
      }
      
      const response = await fetch(url);
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
      
      const response = await fetch(url);
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
      const response = await fetch(`${this.baseUrl}/api/v1/transactions/${transactionId}`);
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