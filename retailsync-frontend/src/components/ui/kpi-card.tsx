import React from 'react';
import { Card, CardContent, CardHeader } from "@/components/ui/card";

interface KpiCardProps {
  title: string;
  value: string | undefined;
  trend?: 'up' | 'down' | 'neutral';
}

export function KpiCard({ title, value, trend }: KpiCardProps) {
  return (
    <Card className="bg-gradient-card shadow-card border-border">
      <CardHeader className="pb-2">
        <h3 className="text-sm font-medium text-muted-foreground">{title}</h3>
      </CardHeader>
      <CardContent>
        <p className="text-3xl font-bold text-foreground">{value}</p>
        {trend && (
          <div className={`text-sm font-medium mt-2 ${
            trend === 'up' ? 'text-success' : 
            trend === 'down' ? 'text-destructive' : 
            'text-muted-foreground'
          }`}>
            {trend === 'up' && '↗'} 
            {trend === 'down' && '↘'} 
            {trend === 'neutral' && '→'}
          </div>
        )}
      </CardContent>
    </Card>
  );
}