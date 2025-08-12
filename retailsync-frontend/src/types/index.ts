// Enhanced types for RetailSync application

export interface User {
  id: number;
  role: 'admin' | 'manager';
  store_id: number | null; // null for admin
}

export interface KpiSummary {
  current_weekly_sales: number;
  previous_weekly_sales: number;
  is_holiday_week: boolean;
}

export interface SalesTrend {
  date: string;
  sales: number;
}

export interface DashboardData {
  store_id: number;
  store_location: string;
  kpi_summary: KpiSummary;
  sales_trend_7_days: SalesTrend[];
}

export interface Product {
  product_id: number;
  product_name: string;
  category_name: string;
  unit_price: number;
  inventory_level: number;
}

export interface TopProduct {
  product_name: string;
  total_sold: number;
}

export interface StoreTransaction {
  location: string;
  transaction_count: number;
}

export interface Transaction {
  transaction_id: number;
  store_id: number;
  store_location: string;
  transaction_date: string;
  total_amount: number;
  customer_id?: number;
  payment_method: string;
  items_count: number;
}

export interface TransactionDetails {
  transaction_id: number;
  store_id: number;
  store_location: string;
  transaction_date: string;
  customer_id?: number;
  payment_method: string;
  total_amount: number;
  items: TransactionItem[];
}

export interface TransactionItem {
  product_id: number;
  product_name: string;
  category_name: string;
  quantity: number;
  unit_price: number;
  total_price: number;
}

export interface Customer {
  customer_id: number;
  age: number;
  gender: string;
  income: number;
  loyalty_level: string;
  // Calculated fields from transactions
  total_spent: number;
  orders_count: number;
  last_order_date?: string;
}

export interface FilterOptions {
  search: string;
  dateFrom?: string;
  dateTo?: string;
  category?: string;
  status?: string;
  minAmount?: number;
  maxAmount?: number;
}

export interface Store {
  store_id: number;
  location: string;
  manager_name: string;
  phone: string;
  email: string;
  opening_hours: string;
}