module AWSAutoscalingTriggers
  AUTOSCALING_TRIGGER = {
    measure_name: %w(CPUUtilization NetworkIn NetworkOut DiskWriteOps DiskReadBytes DiskReadOps DiskWriteBytes Latency RequestCount HealthyHostCount UnhealthyHostCount)
  }
  
end
