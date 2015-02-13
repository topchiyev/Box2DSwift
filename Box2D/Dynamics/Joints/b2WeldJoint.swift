/**
Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
Copyright (c) 2015 - Yohei Yoshihara

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
claim that you wrote the original software. If you use this software
in a product, an acknowledgment in the product documentation would be
appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be
misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.

This version of box2d was developed by Yohei Yoshihara. It is based upon
the original C++ code written by Erin Catto.
*/

import Foundation

/// Weld joint definition. You need to specify local anchor points
/// where they are attached and the relative body angle. The position
/// of the anchor points is important for computing the reaction torque.
public class b2WeldJointDef : b2JointDef {
  public override init() {
    localAnchorA = b2Vec2(0.0, 0.0)
    localAnchorB = b2Vec2(0.0, 0.0)
    referenceAngle = 0.0
    frequencyHz = 0.0
    dampingRatio = 0.0
    super.init()
    type = b2JointType.weldJoint
  }
  
  /// Initialize the bodies, anchors, and reference angle using a world
  /// anchor point.
  public func initialize(bodyA: b2Body, bodyB: b2Body, anchor: b2Vec2) {
    self.bodyA = bodyA
    self.bodyB = bodyB
    self.localAnchorA = bodyA.getLocalPoint(anchor)
    self.localAnchorB = bodyB.getLocalPoint(anchor)
    self.referenceAngle = bodyB.angle - bodyA.angle
  }
  
  /// The local anchor point relative to bodyA's origin.
  public var localAnchorA: b2Vec2
  
  /// The local anchor point relative to bodyB's origin.
  public var localAnchorB: b2Vec2
  
  /// The bodyB angle minus bodyA angle in the reference state (radians).
  public var referenceAngle: b2Float
  
  /// The mass-spring-damper frequency in Hertz. Rotation only.
  /// Disable softness with a value of 0.
  public var frequencyHz: b2Float
  
  /// The damping ratio. 0 = no damping, 1 = critical damping.
  public var dampingRatio: b2Float
}

// MARK: -
/// A weld joint essentially glues two bodies together. A weld joint may
/// distort somewhat because the island constraint solver is approximate.
public class b2WeldJoint : b2Joint {
  public override var anchorA: b2Vec2 {
    return m_bodyA.getWorldPoint(m_localAnchorA)
  }
  public override var anchorB: b2Vec2 {
    return m_bodyB.getWorldPoint(m_localAnchorB)
  }
  
  public override func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
    let P = b2Vec2(m_impulse.x, m_impulse.y)
    return inv_dt * P
  }
  public override func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
    return inv_dt * m_impulse.z
  }
  
  /// The local anchor point relative to bodyA's origin.
  public var localAnchorA: b2Vec2  { return m_localAnchorA }
  
  /// The local anchor point relative to bodyB's origin.
  public var localAnchorB: b2Vec2  { return m_localAnchorB }
  
  /// Get the reference angle.
  public var referenceAngle: b2Float { return m_referenceAngle }
  
  /// Set/get frequency in Hz.
  public func setFrequency(hz: b2Float) { m_frequencyHz = hz }
  public var frequency: b2Float { return m_frequencyHz }
  
  /// Set/get damping ratio.
  public func setDampingRatio(ratio: b2Float) { m_dampingRatio = ratio }
  public var dampingRatio: b2Float { return m_dampingRatio }
  
  /// Dump to println
  public override func dump() {
    let indexA = m_bodyA.m_islandIndex
    let indexB = m_bodyB.m_islandIndex
    
    println("  b2WeldJointDef jd;")
    println("  jd.bodyA = bodies[\(indexA)];")
    println("  jd.bodyB = bodies[\(indexB)];")
    println("  jd.collideConnected = bool(\(m_collideConnected));")
    println("  jd.localAnchorA.set(\(m_localAnchorA.x), \(m_localAnchorA.y));")
    println("  jd.localAnchorB.set(\(m_localAnchorB.x), \(m_localAnchorB.y));")
    println("  jd.referenceAngle = \(m_referenceAngle);")
    println("  jd.frequencyHz = \(m_frequencyHz);")
    println("  jd.dampingRatio = \(m_dampingRatio);")
    println("  joints[\(m_index)] = m_world->createJoint(&jd);")
  }
  
  // MARK: private methods
  
  init(_ def: b2WeldJointDef) {
    m_localAnchorA = def.localAnchorA
    m_localAnchorB = def.localAnchorB
    m_referenceAngle = def.referenceAngle
    m_frequencyHz = def.frequencyHz
    m_dampingRatio = def.dampingRatio
    
    m_impulse = b2Vec3(0.0, 0.0, 0.0)
    super.init(def)
  }
  
  override func initVelocityConstraints(inout data: b2SolverData) {
    m_indexA = m_bodyA.m_islandIndex
    m_indexB = m_bodyB.m_islandIndex
    m_localCenterA = m_bodyA.m_sweep.localCenter
    m_localCenterB = m_bodyB.m_sweep.localCenter
    m_invMassA = m_bodyA.m_invMass
    m_invMassB = m_bodyB.m_invMass
    m_invIA = m_bodyA.m_invI
    m_invIB = m_bodyB.m_invI
    
    var aA = data.positions[m_indexA].a
    var vA = data.velocities[m_indexA].v
    var wA = data.velocities[m_indexA].w
    
    var aB = data.positions[m_indexB].a
    var vB = data.velocities[m_indexB].v
    var wB = data.velocities[m_indexB].w
    
    let qA = b2Rot(aA), qB = b2Rot(aB)
    
    m_rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
    m_rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
    
    // J = [-I -r1_skew I r2_skew]
    //     [ 0       -1 0       1]
    // r_skew = [-ry; rx]
    
    // Matlab
    // K = [ mA+r1y^2*iA+mB+r2y^2*iB,  -r1y*iA*r1x-r2y*iB*r2x,          -r1y*iA-r2y*iB]
    //     [  -r1y*iA*r1x-r2y*iB*r2x, mA+r1x^2*iA+mB+r2x^2*iB,           r1x*iA+r2x*iB]
    //     [          -r1y*iA-r2y*iB,           r1x*iA+r2x*iB,                   iA+iB]
    
    let mA = m_invMassA, mB = m_invMassB
    let iA = m_invIA, iB = m_invIB
    
    var K = b2Mat33()
    K.ex.x = mA + mB + m_rA.y * m_rA.y * iA + m_rB.y * m_rB.y * iB
    K.ey.x = -m_rA.y * m_rA.x * iA - m_rB.y * m_rB.x * iB
    K.ez.x = -m_rA.y * iA - m_rB.y * iB
    K.ex.y = K.ey.x
    K.ey.y = mA + mB + m_rA.x * m_rA.x * iA + m_rB.x * m_rB.x * iB
    K.ez.y = m_rA.x * iA + m_rB.x * iB
    K.ex.z = K.ez.x
    K.ey.z = K.ez.y
    K.ez.z = iA + iB
    
    if m_frequencyHz > 0.0 {
      m_mass = K.getInverse22()
      
      var invM = iA + iB
      let m = invM > 0.0 ? 1.0 / invM : 0.0
      
      let C = aB - aA - m_referenceAngle
      
      // Frequency
      let omega = 2.0 * b2_pi * m_frequencyHz
      
      // Damping coefficient
      let d = 2.0 * m * m_dampingRatio * omega
      
      // Spring stiffness
      let k = m * omega * omega
      
      // magic formulas
      let h = data.step.dt
      m_gamma = h * (d + h * k)
      m_gamma = m_gamma != 0.0 ? 1.0 / m_gamma : 0.0
      m_bias = C * h * k * m_gamma
      
      invM += m_gamma
      m_mass.ez.z = invM != 0.0 ? 1.0 / invM : 0.0
    }
    else {
      m_mass = K.getSymInverse33()
      m_gamma = 0.0
      m_bias = 0.0
    }
    
    if data.step.warmStarting {
      // Scale impulses to support a variable time step.
      m_impulse *= data.step.dtRatio
      
      let P = b2Vec2(m_impulse.x, m_impulse.y)
      
      vA -= mA * P
      wA -= iA * (b2Cross(m_rA, P) + m_impulse.z)
      
      vB += mB * P
      wB += iB * (b2Cross(m_rB, P) + m_impulse.z)
    }
    else {
      m_impulse.setZero()
    }
    
    data.velocities[m_indexA].v = vA
    data.velocities[m_indexA].w = wA
    data.velocities[m_indexB].v = vB
    data.velocities[m_indexB].w = wB
  }
  override func solveVelocityConstraints(inout data: b2SolverData) {
    var vA = data.velocities[m_indexA].v
    var wA = data.velocities[m_indexA].w
    var vB = data.velocities[m_indexB].v
    var wB = data.velocities[m_indexB].w
    
    let mA = m_invMassA, mB = m_invMassB
    let iA = m_invIA, iB = m_invIB
    
    if m_frequencyHz > 0.0 {
      let Cdot2 = wB - wA
      
      let impulse2 = -m_mass.ez.z * (Cdot2 + m_bias + m_gamma * m_impulse.z)
      m_impulse.z += impulse2
      
      wA -= iA * impulse2
      wB += iB * impulse2
      
      let Cdot1 = vB + b2Cross(wB, m_rB) - vA - b2Cross(wA, m_rA)
      
      let impulse1 = -b2Mul22(m_mass, Cdot1)
      m_impulse.x += impulse1.x
      m_impulse.y += impulse1.y
      
      let P = impulse1
      
      vA -= mA * P
      wA -= iA * b2Cross(m_rA, P)
      
      vB += mB * P
      wB += iB * b2Cross(m_rB, P)
    }
    else {
      let Cdot1 = vB + b2Cross(wB, m_rB) - vA - b2Cross(wA, m_rA)
      let Cdot2 = wB - wA
      let Cdot = b2Vec3(Cdot1.x, Cdot1.y, Cdot2)
      
      let impulse = -b2Mul(m_mass, Cdot)
      m_impulse += impulse
      
      let P = b2Vec2(impulse.x, impulse.y)
      
      vA -= mA * P
      wA -= iA * (b2Cross(m_rA, P) + impulse.z)
      
      vB += mB * P
      wB += iB * (b2Cross(m_rB, P) + impulse.z)
    }
    
    data.velocities[m_indexA].v = vA
    data.velocities[m_indexA].w = wA
    data.velocities[m_indexB].v = vB
    data.velocities[m_indexB].w = wB
  }
  override func solvePositionConstraints(inout data: b2SolverData) -> Bool {
    var cA = data.positions[m_indexA].c
    var aA = data.positions[m_indexA].a
    var cB = data.positions[m_indexB].c
    var aB = data.positions[m_indexB].a
    
    let qA = b2Rot(aA), qB = b2Rot(aB)
    
    let mA = m_invMassA, mB = m_invMassB
    let iA = m_invIA, iB = m_invIB
    
    let rA = b2Mul(qA, m_localAnchorA - m_localCenterA)
    let rB = b2Mul(qB, m_localAnchorB - m_localCenterB)
    
    var positionError: b2Float, angularError: b2Float
    
    var K = b2Mat33()
    K.ex.x = mA + mB + rA.y * rA.y * iA + rB.y * rB.y * iB
    K.ey.x = -rA.y * rA.x * iA - rB.y * rB.x * iB
    K.ez.x = -rA.y * iA - rB.y * iB
    K.ex.y = K.ey.x
    K.ey.y = mA + mB + rA.x * rA.x * iA + rB.x * rB.x * iB
    K.ez.y = rA.x * iA + rB.x * iB
    K.ex.z = K.ez.x
    K.ey.z = K.ez.y
    K.ez.z = iA + iB
    
    if m_frequencyHz > 0.0 {
      let C1 =  cB + rB - cA - rA
      
      positionError = C1.length()
      angularError = 0.0
      
      let P = -K.solve22(C1)
      
      cA -= mA * P
      aA -= iA * b2Cross(rA, P)
      
      cB += mB * P
      aB += iB * b2Cross(rB, P)
    }
    else {
      let C1 =  cB + rB - cA - rA
      let C2 = aB - aA - m_referenceAngle
      
      positionError = C1.length()
      angularError = abs(C2)
      
      let C = b2Vec3(C1.x, C1.y, C2)
      
      let impulse = -K.solve33(C)
      let P = b2Vec2(impulse.x, impulse.y)
      
      cA -= mA * P
      aA -= iA * (b2Cross(rA, P) + impulse.z)
      
      cB += mB * P
      aB += iB * (b2Cross(rB, P) + impulse.z)
    }
    
    data.positions[m_indexA].c = cA
    data.positions[m_indexA].a = aA
    data.positions[m_indexB].c = cB
    data.positions[m_indexB].a = aB
    
    return positionError <= b2_linearSlop && angularError <= b2_angularSlop
  }
  
  // MARK: private variables
  
  var m_frequencyHz: b2Float = 0.0
  var m_dampingRatio: b2Float = 0.0
  var m_bias: b2Float = 0.0
  
  // Solver shared
  var m_localAnchorA = b2Vec2()
  var m_localAnchorB = b2Vec2()
  var m_referenceAngle: b2Float = 0.0
  var m_gamma: b2Float = 0.0
  var m_impulse = b2Vec3()
  
  // Solver temp
  var m_indexA: Int = 0
  var m_indexB: Int = 0
  var m_rA = b2Vec2()
  var m_rB = b2Vec2()
  var m_localCenterA = b2Vec2()
  var m_localCenterB = b2Vec2()
  var m_invMassA: b2Float = 0.0
  var m_invMassB: b2Float = 0.0
  var m_invIA: b2Float = 0.0
  var m_invIB: b2Float = 0.0
  var m_mass = b2Mat33()
}