# Multi-GPU Setup Guide for AI Lab Platform

## System Configuration
- **GPUs**: 4× NVIDIA GeForce RTX 2080 Ti (11GB each)
- **Total GPU Memory**: 44GB
- **CUDA Version**: 12.0+
- **PyTorch Version**: 2.7.1+cu126

## ✅ Current Status
Your multi-GPU setup is **fully operational**! All 4 GPUs are:
- Detected by PyTorch
- Communicating via NCCL
- Ready for distributed training

## 🚀 Quick Start

### 1. Access the Multi-GPU Training Notebook
The comprehensive training guide is available at:
```
/home/jovyan/shared/notebooks/multi_gpu_training_guide.ipynb
```

### 2. Simple DataParallel Example
```python
import torch
import torch.nn as nn

# Your model
model = YourModel()

# Enable multi-GPU
if torch.cuda.device_count() > 1:
    print(f"Using {torch.cuda.device_count()} GPUs!")
    model = nn.DataParallel(model)

model = model.cuda()
```

### 3. Environment Variables (Already Set)
```bash
NCCL_DEBUG=INFO
NCCL_IB_DISABLE=1
# IPC mode is enabled via Docker
```

## 📊 Performance Guidelines

### Batch Size Recommendations
| Model | Single GPU | 4 GPUs | Mixed Precision |
|-------|------------|---------|-----------------|
| ResNet50 | 32-48 | 128-192 | 256-384 |
| BERT-Base | 8-12 | 32-48 | 64-96 |
| GPT-2 Small | 4-6 | 16-24 | 32-48 |

### Memory Usage Tips
- Each RTX 2080 Ti has 11GB VRAM
- Use mixed precision to double your batch size
- Monitor with `nvidia-smi` or the notebook functions

## 🛠️ Troubleshooting

### Common Issues and Solutions

1. **NCCL Error**: Already fixed with IPC host mode
2. **Out of Memory**: Reduce batch size or use gradient accumulation
3. **Slow Training**: Enable mixed precision training
4. **Unbalanced GPU Usage**: Ensure batch size is divisible by GPU count

### Monitoring Commands
```bash
# Watch GPU usage in real-time
watch -n 1 nvidia-smi

# Check GPU memory
nvidia-smi --query-gpu=memory.used,memory.total --format=csv

# Monitor specific process
nvidia-smi pmon -i 0,1,2,3
```

## 🎯 Best Practices

1. **Always use the largest batch size that fits in memory**
   - Start with single GPU batch size
   - Multiply by number of GPUs
   - Fine-tune based on memory usage

2. **Enable Mixed Precision Training**
   ```python
   from torch.cuda.amp import autocast, GradScaler
   scaler = GradScaler()
   
   with autocast():
       output = model(input)
       loss = criterion(output, target)
   ```

3. **Use Efficient Data Loading**
   ```python
   DataLoader(dataset,
              batch_size=batch_size,
              num_workers=4,  # 1 per GPU
              pin_memory=True,
              persistent_workers=True)
   ```

4. **Clear Cache Periodically**
   ```python
   torch.cuda.empty_cache()
   ```

## 📈 Expected Performance

With your 4× RTX 2080 Ti setup:
- **Linear scaling**: Expect ~3.5-3.8x speedup over single GPU
- **Mixed precision**: Additional 1.5-2x speedup
- **Total**: Up to 7x faster than single GPU FP32 training

## 🔗 Additional Resources

- Full notebook: `/home/jovyan/shared/notebooks/multi_gpu_training_guide.ipynb`
- PyTorch DDP Tutorial: https://pytorch.org/tutorials/intermediate/ddp_tutorial.html
- NVIDIA Mixed Precision: https://developer.nvidia.com/automatic-mixed-precision

## Need Help?

If you encounter any issues:
1. Check the troubleshooting section above
2. Run the debug functions in the notebook
3. Monitor GPU usage with nvidia-smi
4. Check Docker logs for backend errors

Happy training with your powerful 4-GPU setup! 🚀 