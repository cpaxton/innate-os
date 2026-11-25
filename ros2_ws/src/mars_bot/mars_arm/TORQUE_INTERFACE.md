# Mars torque/contact interface

Status: prototype. The old `/mars/arm/commands` position stream is unchanged;
the new interface adds explicit per-joint modes and unit-consistent state for
whole-body control and contact-rich experiments.

## Topics

| Topic | Type | Direction | Notes |
|---|---|---|---|
| `/mars/arm/joint_commands` | `mars_msgs/ArmCommand` | command | Per-joint `position`, `velocity`, `effort`, `current`, or `pwm`; `lease_id`/`ttl_s` reserved for ownership. |
| `/mars/arm/state_ext` | `mars_msgs/ArmState` | state | Position, velocity, effort (N·m), current (A), load (%), PWM, temperature, mode, validity; contact list when a plant/sensor provides it. |
| `/robot/capabilities` | `std_msgs/String` (JSON) | latched | Machine-readable joint/arm capabilities for Emet and other clients. |
| `/mars/arm/commands` | `std_msgs/Float64MultiArray` | legacy | Six position targets; compatibility path. |
| `/mars/arm/state` | `sensor_msgs/JointState` | legacy | Six-joint position/velocity/effort; `effort` units are legacy (mA or percent). Prefer `state_ext`. |

`state_ext.effort` is always N·m. `current` is always A. `load` is always
percent. No consumer should infer units from joint identity.

## Command modes

`position` and `velocity` write the normal position servo. `effort`, `current`,
and `pwm` are converted to a bounded position-target offset:

```text
q_target = q_meas + clamp(tau / kp_eff, -max_lead, +max_lead)
```

`arm_config.yaml` supplies `kp_eff`, `kd_eff`, `max_lead`, `torque_constant`,
`gear_ratio`, and `stall_torque` per joint. The checked-in values are
placeholders; identify them on the bench before hardware use. A joint without
positive `kp_eff`/`max_lead` rejects torque-mode commands rather than silently
falling back to position.

Current/pressure limits:
- x330 joints (4, 5, 6) have current-control hardware. The firmware can use
  `CURRENT_CONTROLLED_POSITION` and `Goal Current`; the normal config still uses
  position mode, so the position-offset path is the default.
- x430 joints (1, 2, 3) do not have current control. They can only realize the
  position-offset/impedance path; `current` and `pwm` commands are converted
  through the configured stall-torque model and remain approximate.
- The gripper (`joint6`) is current-based position control. Its `goal_current`
  is the grip-force cap; `state_ext` reports measured current/load.

## State

The real driver publishes `state_ext` at `arm_state_ext_rate` (default 100 Hz)
from the 200 Hz control loop. `effort` is estimated:
- x330: `current * torque_constant * gear_ratio`;
- x430: `(load_percent / 100) * stall_torque`.

These are estimates, not a calibrated torque sensor. Contact fields are empty
on hardware without a force/torque sensor.

## Safety

- Torque-mode commands are clipped by `stall_torque` (or the configured torque
  limit), `kp_eff`, `max_lead`, and the joint position limits.
- The command stream carries `ttl_s`; the Emet bridge owns end-to-end stream
  ownership and measured stop. The driver currently accepts the fields but
  keeps the last target, so a client crash is not yet a robot-side stop.
- No powered operating-mode change is performed by this prototype; the existing
  torque_on/off and recovery paths remain authoritative.
- The elbow stall at ~82–84° is a mechanical/thermal issue. Do not use a torque
  command to force through it; identify the elbow on a bench first.

## Simulator

`mars_sim_driver` supports `position` and `effort` modes on `VirtualMars`.
Effort mode applies `qfrc_applied` directly with the same per-joint effort
limit; `joint_state_ext()` and `contact_forces()` expose measured torque and
MuJoCo contact wrenches. `current`/`pwm` modes are not implemented in the sim
yet; the node warns instead of pretending they work.

The sim's `/mars/arm/state_ext` and `/robot/capabilities` mirror the real
driver. Its `/mars/arm/joint_commands` accepts `position`/`effort`; it is a
test surface, not a hardware qualification.
