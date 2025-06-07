import axios, { AxiosInstance, AxiosResponse } from 'axios';

// API Base URL - will use proxy in development
const API_BASE_URL = process.env.REACT_APP_API_URL || '';

// Create axios instance
export const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response: AxiosResponse) => {
    return response;
  },
  (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// API service methods
export const apiService = {
  // Authentication
  login: (email: string, password: string) =>
    apiClient.post('/api/auth/login', { email, password }),
  
  register: (userData: { name: string; email: string; password: string }) =>
    apiClient.post('/api/auth/register', userData),
  
  getCurrentUser: () =>
    apiClient.get('/api/auth/me'),
  
  refreshToken: (refreshToken: string) =>
    apiClient.post('/api/auth/refresh', { refresh_token: refreshToken }),

  // Resources
  getResourceAvailability: () =>
    apiClient.get('/api/resources/availability'),
  
  getResourceUsage: () =>
    apiClient.get('/api/resources/usage'),
  
  getResourceTemplates: () =>
    apiClient.get('/api/resources/templates'),
  
  requestResources: (resourceRequest: any) =>
    apiClient.post('/api/resources/request', resourceRequest),

  // Environments
  getEnvironments: () =>
    apiClient.get('/api/environments'),
  
  getEnvironment: (id: string) =>
    apiClient.get(`/api/environments/${id}`),
  
  stopEnvironment: (id: string) =>
    apiClient.delete(`/api/environments/${id}`),
  
  restartEnvironment: (id: string) =>
    apiClient.post(`/api/environments/${id}/restart`),

  // Monitoring
  getSystemMetrics: () =>
    apiClient.get('/api/monitoring/system'),
  
  getUserMetrics: () =>
    apiClient.get('/api/monitoring/user'),

  // Admin (for admin users)
  getAllUsers: () =>
    apiClient.get('/api/admin/users'),
  
  updateUserQuota: (userId: string, quota: any) =>
    apiClient.put(`/api/admin/users/${userId}/quota`, quota),
};

export default apiService; 