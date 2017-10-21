//
//  Character.swift
//  SpicyHero
//
//  Created by Valmir Junior on 06/10/17.
//  Copyright © 2017 Valmir Junior. All rights reserved.
//

import Foundation
import SceneKit
import GameKit
import simd


// Returns plane / ray intersection distance from ray origin.
func planeIntersect(planeNormal: float3, planeDist: Float, rayOrigin: float3, rayDirection: float3) -> Float {
    return (planeDist - simd_dot(planeNormal, rayOrigin)) / simd_dot(planeNormal, rayDirection)
}

//Enum for name of animations
enum AnimationType : String {
    case walking = "walking"
    case running =  "running"
    case jumping = "jumping"
}

class Character: GKEntity {
    
    //speed multiplier
    static private let speedFactor: CGFloat = 15.0
    static private let initialPosition = float3(0, 5, 0)
    
    // actions
    private let jumpImpulse:Float = 3.0
    var direction = float2()
    var physicsWorld: SCNPhysicsWorld?
    var walkSpeed: CGFloat = 1.0
    var isWalking: Bool = false
    var touchesTheGround = false
	static let walkRunPercentage: Float = 0.5
    
    // Direction
    private var previousUpdateTime: TimeInterval = 0
    private var controllerDirection = float2()
    
    // Character handle
    private(set) var node: SCNNode! // top level node
    private(set) var characterNode: SCNNode!
    
    // MARK: - Initialization
    init(scene: SCNScene) {
        super.init()
        
        self.loadCharacter(scene: scene)
        self.loadAnimations()
        self.loadComponents()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func loadCharacter(scene: SCNScene) {
        /// Load character from external file
        node = scene.rootNode.childNode(withName: "character", recursively: false)
        characterNode = node.childNode(withName: "characterNode", recursively: false)
        //characterNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
    }
    
    //Load all animation in character node
    private func loadAnimations() {
        let animTypes:[AnimationType] = [.walking, .running, .jumping]
        
        for anim in animTypes {
            let animation = SCNAnimationPlayer.withScene(named: "Game.scnassets/character/\(anim.rawValue).dae")
            
            animation.stop()
            
            self.characterNode.addAnimationPlayer(animation, forKey: anim.rawValue)
        }
    }
    
    private func loadComponents() {
        let jumpComponent = JumpComponent(character: self.node, impulse: self.jumpImpulse)
        self.addComponent(jumpComponent)
    }
    
    // MARK: Animatins Functins
    func playAnimation(type: AnimationType) {
        self.characterNode.animationPlayer(forKey: type.rawValue)?.play()
    }
    
    func stopAnimation(type: AnimationType) {
        self.characterNode.animationPlayer(forKey: type.rawValue)?.stop()
    }
    
    
    // MARK: - Controlling the character
    
    private var directionAngle: CGFloat = 0.0 {
        didSet {
            node.runAction(
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
        
        // Move
        if !direction.allZero() {
            characterVelocity = direction * Float(characterSpeed)
            let runModifier = Float(1.0)
            walkSpeed = CGFloat(runModifier * simd_length(direction))
			
            // move character
            directionAngle = CGFloat(atan2f(direction.x, direction.z))
			
			// moving type
			if simd_length(direction) < Character.walkRunPercentage {
				isWalking = true
			}else {
				isWalking = false
			}
		}
        
        if simd_length_squared(characterVelocity) > 10E-4 * 10E-4 {
            let startPosition = node.presentation.simdWorldPosition
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
        node.simdWorldPosition = replacementPoint
    }

    func resetCharacterPosition() {
        node.simdPosition = Character.initialPosition
    }
    
}