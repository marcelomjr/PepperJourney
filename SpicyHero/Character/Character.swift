//
//  Character.swift
//  SpicyHero
//
//  Created by Valmir Junior on 06/10/17.
//  Copyright © 2017 Valmir Junior. All rights reserved.
//

import Foundation
import SceneKit
import simd


// Returns plane / ray intersection distance from ray origin.
func planeIntersect(planeNormal: float3, planeDist: Float, rayOrigin: float3, rayDirection: float3) -> Float {
    return (planeDist - simd_dot(planeNormal, rayOrigin)) / simd_dot(planeNormal, rayDirection)
}

class Character: NSObject {
    
    static private let speedFactor: CGFloat = 2.0
    static private let collisionMargin = Float(0.04)
    static private let initialPosition = float3(0, 5, 0)
    
    // actions
    private let jumpImpulse:Float = 3.0
    var direction = float2()
    var physicsWorld: SCNPhysicsWorld?
    var walkSpeed: CGFloat = 1.0
    var isWalking: Bool = false
    
    // Direction
    private var previousUpdateTime: TimeInterval = 0
    private var controllerDirection = float2()
    
    // Character handle
    private(set) var characterNode: SCNNode! // top level node

    
     private var characterCollisionShape: SCNPhysicsShape?
    
    
    
    
    // MARK: - Initialization
    init(scene: SCNScene) {
        super.init()
        
        self.loadCharacter(scene: scene)
        self.loadAnimations()
    }
    
    private func loadCharacter(scene: SCNScene) {
        /// Load character from external file
        
        characterNode = scene.rootNode.childNode(withName: "character", recursively: true)

    }
    
    private func loadAnimations() {
        let runningAnimation = AnimationUtils.loadAnimation(fromSceneNamed: "Game.scnassets/character/running.scn")
        runningAnimation.speed = 1.0
        runningAnimation.play()
        self.characterNode.addAnimationPlayer(runningAnimation, forKey: "running")
        
        let jumpingAnimation = AnimationUtils.loadAnimation(fromSceneNamed: "Game.scnassets/character/jumping.scn")
        jumpingAnimation.speed = 1.0
        jumpingAnimation.play()
        self.characterNode.addAnimationPlayer(jumpingAnimation, forKey: "jumping")
    }
    
    // MARK: Animatins Functins
    func playJumpingAnimation() {
        self.characterNode.animationPlayer(forKey: "jumping")?.play()
    }
    
    func stopJumpingAnimation() {
        self.characterNode.animationPlayer(forKey: "jumping")?.stop()
    }
    
    func playRunningAnimation() {
        self.characterNode.animationPlayer(forKey: "running")?.play()
    }
    
    func stopRunningAnimation() {
        self.characterNode.animationPlayer(forKey: "running")?.stop()
    }
    
    
    // MARK: - Controlling the character
    
    private var directionAngle: CGFloat = 0.0 {
        didSet {
            characterNode.runAction(
                SCNAction.rotateTo(x: 0.0, y: directionAngle, z: 0.0, duration: 0.1, usesShortestUnitArc:true))
       }
    }
    
    func update(atTime time: TimeInterval, with renderer: SCNSceneRenderer) {
        
        var characterVelocity = float3()
        
        let direction = characterDirection(withPointOfView:renderer.pointOfView)
        
        if previousUpdateTime == 0.0 {
            previousUpdateTime = time
        }
        
        let deltaTime = time - previousUpdateTime
        let characterSpeed = CGFloat(deltaTime) * Character.speedFactor * walkSpeed
        //let virtualFrameCount = Int(deltaTime / (1 / 60.0))
        previousUpdateTime = time
        
        // move
        if !direction.allZero() {
            characterVelocity = direction * Float(characterSpeed)
            let runModifier = Float(1.0)
            walkSpeed = CGFloat(runModifier * simd_length(direction))
            
            // move character
            directionAngle = CGFloat(atan2f(direction.x, direction.z))
            
            self.isWalking = true
        } else {
            self.isWalking = false
        }
        
        if simd_length_squared(characterVelocity) > 10E-4 * 10E-4 {
            let startPosition = characterNode!.presentation.simdWorldPosition
            slideInWorld(fromPosition: startPosition, velocity: characterVelocity)
        }
        
    }
    
    
    func characterDirection(withPointOfView pointOfView: SCNNode?) -> float3 {
        let controllerDir = self.direction
        if controllerDir.isEmpty {
            return float3()
        }
        
        var directionWorld = float3()
        if let pov = pointOfView {
            let p1 = pov.presentation.simdConvertPosition(float3(controllerDir.x, 0.0, controllerDir.y), to: nil)
            let p0 = pov.presentation.simdConvertPosition(float3(), to: nil)
            directionWorld = p1 - p0
            directionWorld.y = 0
            
            if simd_bool(directionWorld != float3()) {
                let minControllerSpeedFactor = Float(0.2)
                let maxControllerSpeedFactor = Float(1.0)
                let speed = simd_length(controllerDir) * (maxControllerSpeedFactor - minControllerSpeedFactor) + minControllerSpeedFactor
                directionWorld = speed * simd_normalize(directionWorld)
            }
        }
        return directionWorld
    }
    
    
    func slideInWorld(fromPosition start: float3, velocity: float3) {
        var stop: Bool = false
        
        var replacementPoint = start
        
        let start = start
        let velocity = velocity
       // let options: [SCNPhysicsWorld.TestOption: Any] = [
        //    SCNPhysicsWorld.TestOption.collisionBitMask: Bitmask.collision.rawValue,
        //    SCNPhysicsWorld.TestOption.searchMode: SCNPhysicsWorld.TestSearchMode.closest]
        while !stop {
            replacementPoint = start + velocity
            stop = true
        }
        characterNode!.simdWorldPosition = replacementPoint
    }

    func resetCharacterPosition() {
        characterNode.simdPosition = Character.initialPosition
    }
    
    func jump()
    {
        print("jump")
        let currentPosition = self.characterNode.presentation.position
        let jumpDirection = currentPosition.y + jumpImpulse
        let direction = SCNVector3(0, jumpDirection, 0)
        self.characterNode.physicsBody?.applyForce(direction, asImpulse: true)
    }
}
