module RSchema
  module AWSAutoscalingTriggers
    MEASURES = %w(CPUUtilization NetworkIn NetworkOut DiskWriteOps DiskReadBytes DiskReadOps DiskWriteBytes Latency RequestCount HealthyHostCount UnhealthyHostCount)
    UNITS = %W(Seconds Percent Bytes Bits Count Bytes/Second Bits/Second Count/Second)
    STATISTIC = %W(Minimum Maximum Sum Average)
  end
end
