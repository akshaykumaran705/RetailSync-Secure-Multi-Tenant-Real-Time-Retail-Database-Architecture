import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Building2, MapPin, Phone, Mail, Clock } from 'lucide-react';
import { apiService } from '@/lib/api';
import { User, Store as StoreType } from '@/types';

interface StoreSelectorProps {
  user: User;
  selectedStoreId: number | null;
  onStoreSelect: (storeId: number | null) => void;
}

export function StoreSelector({ user, selectedStoreId, onStoreSelect }: StoreSelectorProps) {
  const [stores, setStores] = useState<StoreType[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (user.role === 'admin') {
      loadStores();
    }
  }, [user.role]);

  const loadStores = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await apiService.getAllStores();
      
      if (response.success && response.data) {
        setStores(response.data);
      } else {
        setError(response.error || 'Failed to load stores');
      }
    } catch (err) {
      setError('Failed to load stores');
    } finally {
      setLoading(false);
    }
  };

  // If user is not admin, don't show store selector
  if (user.role !== 'admin') {
    return null;
  }

  if (loading) {
    return (
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardContent className="p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary"></div>
            <span className="ml-2 text-muted-foreground">Loading stores...</span>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
        <CardContent className="p-6">
          <div className="text-center text-destructive">
            <p className="font-semibold mb-2">Error Loading Stores</p>
            <p className="text-sm">{error}</p>
            <Button 
              onClick={loadStores} 
              variant="outline" 
              className="mt-3 border-border hover:bg-secondary"
            >
              Retry
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="bg-gradient-card shadow-card border-border animate-slide-up">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-foreground">
          <Building2 size={20} />
          Store Selection
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* All Stores Option */}
        <div className="flex items-center justify-between p-4 bg-background/50 rounded-lg border border-border/50">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-primary/20">
              <Building2 size={20} className="text-primary" />
            </div>
            <div>
              <h3 className="font-semibold text-foreground">All Stores</h3>
              <p className="text-sm text-muted-foreground">View data from all stores combined</p>
            </div>
          </div>
          <Button
            variant={selectedStoreId === null ? "default" : "outline"}
            onClick={() => onStoreSelect(null)}
            className={selectedStoreId === null ? "bg-primary" : "border-border hover:bg-secondary"}
          >
            {selectedStoreId === null ? "Selected" : "Select"}
          </Button>
        </div>

        {/* Individual Store Options */}
        <div className="space-y-3">
          {stores.map((store) => (
            <div 
              key={store.store_id} 
              className="flex items-center justify-between p-4 bg-background/50 rounded-lg border border-border/50 hover:bg-background/70 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-blue-500/20">
                  <MapPin size={20} className="text-blue-600" />
                </div>
                <div>
                  <h3 className="font-semibold text-foreground">{store.location}</h3>
                  <div className="flex items-center gap-4 text-sm text-muted-foreground">
                    <div className="flex items-center gap-1">
                      <Building2 size={14} />
                      <span>Store {store.store_id}</span>
                    </div>
                    {store.manager_name && (
                      <div className="flex items-center gap-1">
                        <Mail size={14} />
                        <span>{store.manager_name}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
              <Button
                variant={selectedStoreId === store.store_id ? "default" : "outline"}
                onClick={() => onStoreSelect(store.store_id)}
                className={selectedStoreId === store.store_id ? "bg-primary" : "border-border hover:bg-secondary"}
              >
                {selectedStoreId === store.store_id ? "Selected" : "Select"}
              </Button>
            </div>
          ))}
        </div>

        {/* Current Selection Summary */}
        {selectedStoreId !== null && (
          <div className="mt-4 p-3 bg-primary/10 rounded-lg border border-primary/20">
            <div className="flex items-center gap-2 text-primary">
              <MapPin size={16} />
              <span className="font-medium">
                Currently viewing: Store {selectedStoreId} - {stores.find(s => s.store_id === selectedStoreId)?.location}
              </span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
} 