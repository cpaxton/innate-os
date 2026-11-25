# Multi-mode arm state at the control rate. contact fields are empty on
# hardware without a force/torque sensor.
std_msgs/Header header
JointStateExt[] joints
bool torque_enabled
string[] contact_names
# Flattened 6-axis wrench per contact name: fx fy fz tx ty tz.
float64[] contact_wrenches
