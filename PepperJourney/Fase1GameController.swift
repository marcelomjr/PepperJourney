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

class Fase1GameController: GameController {
    
    override func resetSounds()
    {
        // Restart the background music
        self.soundController.playbackgroundMusic(soundName: "backgroundMusic", loops: true, node: self.cameraNode)
        
    }
    
    override func stopSounds()
    {
        // Clean all the sounds
        soundController.stopSoundsFromNode(node: self.cameraNode)
        soundController.stopSoundsFromNode(node: self.character.characterNode)
    }
    override func setupSounds() {
        
        self.soundController.loadSound(fileName: "gameBackground.mp3", soundName: "backgroundMusic", volume: 0.5)
        
        
        self.soundController.loadSound(fileName: "GameOver-Game_over.wav", soundName: "gameOverSound", volume: 1)
        
        // Finish Level sound
        self.soundController.loadSound(fileName: "FinishLevel-jingle-win-00.wav", soundName: "FinishLevelSound", volume: 1)
        // Potato Yell
        self.soundController.loadSound(fileName: "Yell - small-fairy-hit-moan.wav", soundName: "PotatoYell")
        
        //setup character sounds
        self.soundController.loadSound(fileName: "jump.wav", soundName: "jump", volume: 30.0)
        
        // Add the sound points
        self.entityManager.addPepperSoundPoints()
        
    }
    override func setupCharacter() {
        // create the character with your components
        self.character = self.entityManager.character
        self.character.setupCharacter()
        
        characterStateMachine = GKStateMachine(states: [
            StandingState(scene: scene, character: character),
            WalkingState(scene: scene, character: character),
            RunningState(scene: scene, character: character),
            JumpingState(scene: scene, character: character),
            JumpingMoveState(scene: scene, character: character)
            ])
        
    }
    
    override func setupCamera() {
        self.followingCamera = self.scene.rootNode.childNode(withName: "followingCamera", recursively: true)
        
        self.cameraNode = self.scene.rootNode.childNode(withName: "camera", recursively: true)!
        self.cameraInitialPosition = cameraNode.presentation.position
        
        let lookAtConstraint = SCNLookAtConstraint(target: self.character.visualTarget)
        lookAtConstraint.isGimbalLockEnabled = true
        lookAtConstraint.influenceFactor = 1
        
        let distanceConstraint = SCNDistanceConstraint(target: self.character.characterNode)
        distanceConstraint.minimumDistance = 45
        distanceConstraint.maximumDistance = 45
        
        let keepAltitude = SCNTransformConstraint.positionConstraint(inWorldSpace: true) { (node: SCNNode, position: SCNVector3) -> SCNVector3 in
            var position = float3(position)
            position.y = self.character.characterNode.presentation.position.y + 20
            return SCNVector3(position)
        }
        
        self.cameraNode.constraints = [lookAtConstraint, distanceConstraint , keepAltitude]
    }
    
    override func setupGame() {
        gameStateMachine = GKStateMachine(states: [
            PauseState(scene: scene),
            PlayState(scene: scene) ])
        
        self.gameStateMachine.enter(PauseState.self)
    }
    
    // MARK: Initializer
    override init(scnView: SCNView) {
        super.init(scnView: scnView)

        
        //load the main scene
        self.scene = SCNScene(named: "Game.scnassets/fases/fase1.scn")
        
        //setup game state machine
        self.setupGame()
        
        self.scene.physicsWorld.contactDelegate = self
        
        scnView.scene = scene
        
        //self.scnView.debugOptions = SCNDebugOptions.showPhysicsShapes
        //self.scnView.showsStatistics = true
        
        // Create the entity manager system
        self.entityManager = EntityManager(scene: self.scene, gameController: self, soundController: self.soundController)
        
        //load the character
        self.setupCharacter()
        
        self.setupCamera()
        
        //setup tap to start
        self.setupTapToStart()
        
        // Pre-load all the audios of the game in the memory
        self.setupSounds()
        
        
    }
    
    override func initializeTheGame () {
        //        guard let node = character.component(ofType: ModelComponent.self)?.modelNode else
        //        {
        //            fatalError("Character node not found")
        //        }
        
        // Show de character
        self.character.characterNode.isHidden = false
        
        self.entityManager.setupGameInitialization()
        
        // Reset of all the sounds
        self.resetSounds()
        
        self.character.setupCharacter()
        
        self.cameraNode.position = self.cameraInitialPosition
        
    }
    
    override func setupTapToStart() {
        
        // Do the setup to restart the game
        self.prepereToStartGame()
        
        let tapOverlay = SKScene(fileNamed: "StartOverlay.sks") as! StartOverlay
        tapOverlay.gameOptionsDelegate = self
        tapOverlay.scaleMode = .aspectFill
        self.scnView.overlaySKScene = tapOverlay
        
    }
    override func prepereToStartGame()
    {
        self.stopSounds()
        
        entityManager.killAllPotatoes()
        
        self.character.characterNode.isHidden = true
    }
    
    override func setupGameOver() {
        
        // Do the setup to restart the game
        self.prepereToStartGame()
        
        self.soundController.playSoundEffect(soundName: "gameOverSound", loops: false, node: self.cameraNode)
        
        let gameOverOverlay = SKScene(fileNamed: "GameOverOverlay.sks") as! GameOverOverlay
        gameOverOverlay.gameOptionsDelegate = self
        gameOverOverlay.scaleMode = .aspectFill
        self.scnView.overlaySKScene = gameOverOverlay
        
        //self.gameStateMachine.enter(PauseState.self)
        
    }
    
    override func setupFinishLevel() {
        self.prepereToStartGame()
        self.soundController.playSoundEffect(soundName: "FinishLevelSound", loops: false, node: self.cameraNode)
        
        let finishLevelOverlay = SKScene(fileNamed: "FinishOverlay.sks") as! FinishOverlay
        finishLevelOverlay.gameOptionsDelegate = self
        finishLevelOverlay.scaleMode = .aspectFill
        self.scnView.overlaySKScene = finishLevelOverlay
        
        self.gameStateMachine.enter(PauseState.self)
        
        self.cutSceneDelegate?.playCutScene(videoPath: "cutscene1.mp4")
    }
    
    override func startGame() {
        super.startGame()
        // Inittialize the game with the defaults settings.
        
        //here we can hidden indicators
        controlsOverlay?.isAttackHidden = true
    }
        
    override func handleWithPhysicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        var characterNode: SCNNode?
        var anotherNode: SCNNode?
        var potatoNode: SCNNode?
        
        
        if contact.nodeA == self.character.characterNode {
            
            characterNode = contact.nodeA
            
            anotherNode = contact.nodeB
        }
            
        else if contact.nodeB == self.character.characterNode
        {
            characterNode = contact.nodeB
            
            anotherNode = contact.nodeA
        }
        
        if characterNode != nil
        {
            
            
            if self.character.isJumping && anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.solidSurface.rawValue {
                
                //set the jumping flag to false
                self.character.isJumping = false
                
                //stop impulse animation
                self.character.stopAnimation(type: .jumpingImpulse)
                
                //play landing animation
                self.character.playAnimationOnce(type: .jumpingLanding)
                
                
                //go to standing state mode
                self.characterStateMachine.enter(StandingState.self)
            }
                // foi pego por uma batata
            else if anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.potato.rawValue {
                DispatchQueue.main.async { [unowned self] in
                    if let lifeComponent = self.character.component(ofType: LifeComponent.self) {
                        if lifeComponent.canReceiveDamage {
                            lifeComponent.receiveDamage(enemyCategory: .potato, waitTime: 0.2)
                            let currentLife = lifeComponent.getLifePercentage()
                            
                            if currentLife <= 0 {
                                self.setupGameOver()
                                return
                            }
                            self.overlayDelegate?.updateLifeIndicator(percentage: currentLife)
                        }
                    }
                }
                
            }
                
            else if anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.lake.rawValue {
                
                if anotherNode?.name == "lakeBottom"
                {
                    DispatchQueue.main.async { [unowned self] in
                        self.setupGameOver()
                    }
                }
                    // When the character thouches the lake surface
                else if anotherNode?.name == "lakeSurface"
                {
                    let sinkComponent = self.entityManager.getComponent(entity: self.character, ofType: SinkComponent.self) as! SinkComponent
                    sinkComponent.sinkInWater()
                    
                    //pause controls
                    self.controlsOverlay?.isPausedControl = true
                }
            }
                
                // venceu a fase
            else if anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.finalLevel.rawValue {
                
                DispatchQueue.main.async { [unowned self] in
                    self.setupFinishLevel()
                }
                
            }
            // ja resolveu o que tinha que fazer aqui com o character
            return
        }
        
        // Found potato
        if contact.nodeA.physicsBody?.categoryBitMask == CategoryMaskType.potato.rawValue
        {
            potatoNode = contact.nodeA
            anotherNode = contact.nodeB
        }
        else if contact.nodeB.physicsBody?.categoryBitMask == CategoryMaskType.potato.rawValue
        {
            potatoNode = contact.nodeB
            anotherNode = contact.nodeA
        }
        
        if let potatoNode = potatoNode, anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.lake.rawValue
        {
            let lakeNode = anotherNode!
            
            if lakeNode.name == "lakeBottom"
            {
                self.entityManager.killAPotato(node: potatoNode)
            }
            else if lakeNode.name == "lakeSurface"
            {
                // If the potato yet exists it will be found
                if let potatoEntity = self.entityManager.getPotatoEntity(node: potatoNode) {
                    let sinkComponent = self.entityManager.getComponent(entity: potatoEntity, ofType: SinkComponent.self) as! SinkComponent
                    sinkComponent.sinkInWater()
                    potatoEntity.removeComponent(ofType: SeekComponent.self)
                }
            }
        }
        else if let potatoNode = potatoNode, anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.fireBall.rawValue
        {
            
            if self.entityManager.killAPotato(node: potatoNode)
            {
                self.soundController.playSoundEffect(soundName: "PotatoYell", loops: false, node: self.cameraNode)
            }
            
        }
    }
}



