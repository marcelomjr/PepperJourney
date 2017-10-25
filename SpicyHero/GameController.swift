//
//  GameController.swift
//  SpicyHero
//
//  Created by Valmir Junior on 06/10/17.
//  Copyright © 2017 Valmir Junior. All rights reserved.
//

import Foundation
import GameController
import SceneKit
import SpriteKit
import GameplayKit


class GameController: NSObject, SCNSceneRendererDelegate {
    
    var character: Character!
    var characterStateMachine: GKStateMachine!
    var potato: PotatoEntity!
    
    var floor: SCNNode!
    
    private var scene: SCNScene!
    private weak var sceneRenderer: SCNSceneRenderer?
    private var overlay: Overlay?
    
    // Camera and targets
    private var cameraNode: SCNNode!
    private var pepperNode: SCNNode!
    
    // MARK: - Controling the character
    
    var characterDirection: vector_float2 {
        get {
            return character!.direction
        }
        set {
            var direction = newValue
            let l = simd_length(direction)
            if l > 1.0 {
                direction *= 1 / l
            }
            character!.direction = direction
        }
    }
    
    
    func setupCharacter() {
        character = Character(scene: scene!, jumpDelegate: self)
        character.node.physicsBody?.categoryBitMask = 0b1
        
        characterStateMachine = GKStateMachine(states: [
            StandingState(scene: scene, character: character),
            WalkingState(scene: scene, character: character),
            RunningState(scene: scene, character: character),
            JumpingState(scene: scene, character: character)
            ])
        
        characterStateMachine.enter(StandingState.self)
    }
    
    func setupCamera() {
        self.cameraNode = self.scene.rootNode.childNode(withName: "camera", recursively: true)!
        
        guard let characterNode = self.character.node else
        {
            print("Error with the target of the follow camera")
            return
        }
        let lookAtConstraint = SCNLookAtConstraint(target: self.character.visualTarget)
        lookAtConstraint.isGimbalLockEnabled = true
        //lookAtConstraint.influenceFactor = 0.5
        
        let distanceConstraint = SCNDistanceConstraint(target: characterNode)
        
        distanceConstraint.minimumDistance = 50//15
        distanceConstraint.maximumDistance = 50//15
        
        let keepAltitude = SCNTransformConstraint.positionConstraint(inWorldSpace: true) { (node: SCNNode, position: SCNVector3) -> SCNVector3 in
            var position = float3(position)
            position.y = self.character.node.presentation.position.y + 30//10
            return SCNVector3(position)
        }
        
        self.cameraNode.constraints = [lookAtConstraint, distanceConstraint, keepAltitude]
    }
    
    func setupNodes() {
        self.floor = self.scene.rootNode.childNode(withName: "floor", recursively: false)
    }
    
    // MARK: Initializer
    init(scnView: SCNView)
    {
        super.init()
        
        sceneRenderer = scnView
        sceneRenderer!.delegate = self
        
        // Uncomment to show statistics such as fps and timing information
        //scnView.showsStatistics = true
        
        
        //load the main scene
        //
        self.scene = SCNScene(named: "Game.scnassets/level1.scn")
        
        let overlay = SKScene(fileNamed: "overlay.sks") as! Overlay
        overlay.padDelegate = self
        overlay.movesDelegate = self
        overlay.scaleMode = .aspectFill
        scnView.overlaySKScene = overlay
        
        //load the character
        self.setupCharacter()
        
        self.setupCamera()
        
        self.setupNodes()
        
    
        scnView.scene = scene
        
        scnView.scene?.physicsWorld.contactDelegate = self

        //select the point of view to use
        //sceneRenderer!.pointOfView = self.cameraNode
        
        let trackingAgent = character.component(ofType: GKAgent3D.self)!
        
        self.potato  = PotatoEntity(model: .model1, scene: scene, position: SCNVector3(4,0,10), trakingAgent: trackingAgent)
        
//        let potato2  = PotatoEntity(model: .model2, scene: scene, position: SCNVector3(3,4,0))
//        let potato3  = PotatoEntity(model: .model2, scene: scene, position: SCNVector3(4,5,0))
        
    }
    
    
    // MARK: - Update
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)
    {
        // update characters
        character!.update(atTime: time, with: renderer)
        let seekComponent = self.potato.component(ofType: SeekComponent.self)!
        seekComponent.update(deltaTime: time)
        
        let component = self.character.component(ofType: GKAgent3D.self)!
        component.position.x = self.character.node.presentation.position.x
        component.position.z = self.character.node.presentation.position.z
       //print(component.rotation.columns.1)

    }
    
    
}

extension GameController : PadOverlayDelegate {
    
    func padOverlayVirtualStickInteractionDidStart(_ padNode: PadOverlay) {
        characterDirection = float2(Float(padNode.stickPosition.x), -Float(padNode.stickPosition.y))
    }
    
    
    func padOverlayVirtualStickInteractionDidChange(_ padNode: PadOverlay) {
        characterDirection = float2(Float(padNode.stickPosition.x), -Float(padNode.stickPosition.y))
        
        if(character.isWalking) {
            self.characterStateMachine.enter(WalkingState.self)
        }
        else {
            self.characterStateMachine.enter(RunningState.self)
        }
        
    }
    
    
    func padOverlayVirtualStickInteractionDidEnd(_ padNode: PadOverlay) {
        characterDirection = [0, 0]
        
        self.characterStateMachine.enter(StandingState.self)
    }
    
}

extension GameController : CharacterMovesDelegate {
    func jump() {
        self.characterStateMachine.enter(JumpingState.self)
    }
    
    func attack() {
        
    }
}


extension GameController : JumpDelegate {
    
    func didJumpBegin(node: SCNNode) {
        if(node == character.node) {
            self.character.isJumping = true
        }
    }
}

extension GameController : SCNPhysicsContactDelegate {

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print("contact")
    }
}
