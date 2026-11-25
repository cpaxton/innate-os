# Multi-mode arm command. The existing /mars/arm/commands position stream is
# kept as a compatibility path; this message carries per-joint mode and limits.
std_msgs/Header header
string lease_id
float64 ttl_s
JointCommand[] joints
