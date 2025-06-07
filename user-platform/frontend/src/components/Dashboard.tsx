import React, { useState, useEffect } from 'react';
import { 
  Box, 
  Grid, 
  Card, 
  CardContent, 
  Typography, 
  Button, 
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Slider,
  TextField,
  Alert,
  CircularProgress,
  LinearProgress
} from '@mui/material';
import { 
  Computer as ComputerIcon,
  Memory as MemoryIcon,
  Storage as StorageIcon,
  Speed as SpeedIcon,
  PlayArrow as PlayIcon,
  Stop as StopIcon
} from '@mui/icons-material';

import { apiClient } from '../services/api';
import { useAuth } from '../hooks/useAuth';

interface Environment {
  id: string;
  name: string;
  environment_type: string;
  gpu_count: number;
  gpu_type: string;
  cpu_cores: number;
  memory_gb: number;
  status: string;
  access_url?: string;
  created_at: string;
}

interface ResourceUsage {
  current_gpus: number;
  current_cpu_cores: number;
  current_memory_gb: number;
  current_storage_gb: number;
  current_environments: number;
  quota: {
    max_gpus: number;
    max_cpu_cores: number;
    max_memory_gb: number;
    max_storage_gb: number;
    max_environments: number;
  };
}

interface Template {
  id: string;
  name: string;
  description: string;
  environment_type: string;
  recommended_gpu: number;
  recommended_memory: number;
  packages: {
    conda: string[];
    pip: string[];
  };
}

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const [environments, setEnvironments] = useState<Environment[]>([]);
  const [resourceUsage, setResourceUsage] = useState<ResourceUsage | null>(null);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>('');

  // Create environment form state
  const [formData, setFormData] = useState({
    environment_type: 'jupyter',
    gpu_count: 1,
    gpu_type: 'rtx-3090',
    cpu_cores: 4,
    memory_gb: 16,
    storage_gb: 50,
    environment_name: '',
    conda_packages: [] as string[],
    pip_packages: [] as string[]
  });

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    setLoading(true);
    try {
      const [envsResponse, usageResponse, templatesResponse] = await Promise.all([
        apiClient.get('/api/environments'),
        apiClient.get('/api/resources/usage'),
        apiClient.get('/api/resources/templates')
      ]);

      setEnvironments(envsResponse.data);
      setResourceUsage(usageResponse.data);
      setTemplates(templatesResponse.data.templates);
    } catch (err: any) {
      setError('Failed to load dashboard data');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateEnvironment = async () => {
    setLoading(true);
    setError('');

    try {
      const response = await apiClient.post('/api/resources/request', formData);
      
      // Reset form and close dialog
      setFormData({
        environment_type: 'jupyter',
        gpu_count: 1,
        gpu_type: 'rtx-3090',
        cpu_cores: 4,
        memory_gb: 16,
        storage_gb: 50,
        environment_name: '',
        conda_packages: [],
        pip_packages: []
      });
      setShowCreateDialog(false);
      setSelectedTemplate(null);
      
      // Reload dashboard data
      await loadDashboardData();
      
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to create environment');
    } finally {
      setLoading(false);
    }
  };

  const handleTemplateSelect = (template: Template) => {
    setSelectedTemplate(template);
    setFormData({
      ...formData,
      environment_type: template.environment_type,
      gpu_count: template.recommended_gpu,
      memory_gb: template.recommended_memory,
      environment_name: `${template.id}-${Date.now()}`,
      conda_packages: template.packages.conda,
      pip_packages: template.packages.pip
    });
    setShowCreateDialog(true);
  };

  const getStatusColor = (status: string) => {
    const colors: { [key: string]: 'success' | 'warning' | 'error' | 'info' } = {
      running: 'success',
      starting: 'warning',
      stopping: 'warning',
      failed: 'error',
      creating: 'info'
    };
    return colors[status] || 'default';
  };

  const formatGPUUsage = (current: number, max: number) => {
    const percentage = (current / max) * 100;
    return { percentage, text: `${current}/${max} GPUs` };
  };

  if (loading && !resourceUsage) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        AI Lab Dashboard
      </Typography>
      
      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
        Welcome back, {user?.name}! Manage your ML environments and GPU resources.
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {/* Resource Usage Overview */}
      {resourceUsage && (
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} md={3}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" mb={2}>
                  <ComputerIcon color="primary" sx={{ mr: 1 }} />
                  <Typography variant="h6">GPU Usage</Typography>
                </Box>
                <Typography variant="h4" color="primary">
                  {resourceUsage.current_gpus}/{resourceUsage.quota.max_gpus}
                </Typography>
                <LinearProgress 
                  variant="determinate" 
                  value={formatGPUUsage(resourceUsage.current_gpus, resourceUsage.quota.max_gpus).percentage}
                  sx={{ mt: 1 }}
                />
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} md={3}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" mb={2}>
                  <MemoryIcon color="secondary" sx={{ mr: 1 }} />
                  <Typography variant="h6">Memory</Typography>
                </Box>
                <Typography variant="h4" color="secondary">
                  {resourceUsage.current_memory_gb}GB
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  of {resourceUsage.quota.max_memory_gb}GB
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} md={3}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" mb={2}>
                  <SpeedIcon color="info" sx={{ mr: 1 }} />
                  <Typography variant="h6">CPU Cores</Typography>
                </Box>
                <Typography variant="h4" color="info">
                  {resourceUsage.current_cpu_cores}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  of {resourceUsage.quota.max_cpu_cores} cores
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} md={3}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" mb={2}>
                  <StorageIcon color="warning" sx={{ mr: 1 }} />
                  <Typography variant="h6">Environments</Typography>
                </Box>
                <Typography variant="h4" color="warning">
                  {resourceUsage.current_environments}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  of {resourceUsage.quota.max_environments} max
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Environment Templates */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" gutterBottom>
          Quick Start Templates
        </Typography>
        
        <Grid container spacing={2}>
          {templates.map((template) => (
            <Grid item xs={12} md={6} lg={3} key={template.id}>
              <Card 
                sx={{ cursor: 'pointer', height: '100%' }}
                onClick={() => handleTemplateSelect(template)}
              >
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    {template.name}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {template.description}
                  </Typography>
                  <Box display="flex" gap={1} flexWrap="wrap">
                    <Chip 
                      label={`${template.recommended_gpu} GPU`} 
                      size="small" 
                      color="primary" 
                    />
                    <Chip 
                      label={`${template.recommended_memory}GB RAM`} 
                      size="small" 
                      color="secondary" 
                    />
                    <Chip 
                      label={template.environment_type} 
                      size="small" 
                      variant="outlined" 
                    />
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Box>

      {/* Current Environments */}
      <Box>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="h5">
            Your Environments
          </Typography>
          <Button 
            variant="contained" 
            onClick={() => setShowCreateDialog(true)}
            disabled={loading}
          >
            Create Environment
          </Button>
        </Box>

        <Grid container spacing={2}>
          {environments.map((env) => (
            <Grid item xs={12} md={6} lg={4} key={env.id}>
              <Card>
                <CardContent>
                  <Box display="flex" justifyContent="space-between" alignItems="start" mb={2}>
                    <Typography variant="h6">
                      {env.name}
                    </Typography>
                    <Chip 
                      label={env.status} 
                      color={getStatusColor(env.status)}
                      size="small"
                    />
                  </Box>
                  
                  <Typography variant="body2" color="text.secondary" gutterBottom>
                    {env.environment_type.toUpperCase()} • {env.gpu_count}x {env.gpu_type}
                  </Typography>
                  
                  <Typography variant="body2" color="text.secondary" gutterBottom>
                    {env.cpu_cores} cores • {env.memory_gb}GB RAM
                  </Typography>

                  <Box display="flex" gap={1} mt={2}>
                    {env.status === 'running' && env.access_url && (
                      <Button 
                        size="small" 
                        variant="contained" 
                        startIcon={<PlayIcon />}
                        href={env.access_url}
                        target="_blank"
                      >
                        Open
                      </Button>
                    )}
                    
                    {env.status === 'running' && (
                      <Button 
                        size="small" 
                        variant="outlined" 
                        color="error"
                        startIcon={<StopIcon />}
                      >
                        Stop
                      </Button>
                    )}
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>

        {environments.length === 0 && (
          <Card>
            <CardContent sx={{ textAlign: 'center', py: 6 }}>
              <Typography variant="h6" color="text.secondary" gutterBottom>
                No environments yet
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                Create your first ML environment to get started
              </Typography>
              <Button 
                variant="contained" 
                onClick={() => setShowCreateDialog(true)}
              >
                Create Environment
              </Button>
            </CardContent>
          </Card>
        )}
      </Box>

      {/* Create Environment Dialog */}
      <Dialog 
        open={showCreateDialog} 
        onClose={() => setShowCreateDialog(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          Create New Environment
          {selectedTemplate && (
            <Typography variant="subtitle2" color="text.secondary">
              Based on: {selectedTemplate.name}
            </Typography>
          )}
        </DialogTitle>
        
        <DialogContent>
          <Grid container spacing={3} sx={{ mt: 1 }}>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Environment Name"
                value={formData.environment_name}
                onChange={(e) => setFormData({...formData, environment_name: e.target.value})}
              />
            </Grid>
            
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Environment Type</InputLabel>
                <Select
                  value={formData.environment_type}
                  onChange={(e) => setFormData({...formData, environment_type: e.target.value})}
                >
                  <MenuItem value="jupyter">JupyterLab</MenuItem>
                  <MenuItem value="vscode">VS Code</MenuItem>
                  <MenuItem value="custom">Custom</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            <Grid item xs={12} md={6}>
              <Typography gutterBottom>GPU Count: {formData.gpu_count}</Typography>
              <Slider
                value={formData.gpu_count}
                onChange={(_, value) => setFormData({...formData, gpu_count: value as number})}
                min={1}
                max={4}
                step={1}
                marks
                valueLabelDisplay="auto"
              />
            </Grid>

            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>GPU Type</InputLabel>
                <Select
                  value={formData.gpu_type}
                  onChange={(e) => setFormData({...formData, gpu_type: e.target.value})}
                >
                  <MenuItem value="rtx-3090">RTX 3090 (24GB)</MenuItem>
                  <MenuItem value="rtx-2080-ti">RTX 2080 Ti (11GB)</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            <Grid item xs={12} md={6}>
              <Typography gutterBottom>CPU Cores: {formData.cpu_cores}</Typography>
              <Slider
                value={formData.cpu_cores}
                onChange={(_, value) => setFormData({...formData, cpu_cores: value as number})}
                min={1}
                max={16}
                step={1}
                marks={[{value: 1, label: '1'}, {value: 8, label: '8'}, {value: 16, label: '16'}]}
                valueLabelDisplay="auto"
              />
            </Grid>

            <Grid item xs={12} md={6}>
              <Typography gutterBottom>Memory: {formData.memory_gb}GB</Typography>
              <Slider
                value={formData.memory_gb}
                onChange={(_, value) => setFormData({...formData, memory_gb: value as number})}
                min={4}
                max={64}
                step={4}
                marks={[{value: 4, label: '4GB'}, {value: 32, label: '32GB'}, {value: 64, label: '64GB'}]}
                valueLabelDisplay="auto"
              />
            </Grid>
          </Grid>
        </DialogContent>
        
        <DialogActions>
          <Button onClick={() => setShowCreateDialog(false)}>
            Cancel
          </Button>
          <Button 
            onClick={handleCreateEnvironment} 
            variant="contained"
            disabled={loading || !formData.environment_name}
          >
            {loading ? <CircularProgress size={20} /> : 'Create Environment'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Dashboard; 