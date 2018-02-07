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
    
    
    private var isWinner:Bool = false
    private var firstTimePlayingTutorial:Bool = true
       
    override func stopSounds() {
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
        
        self.soundController.loadSound(fileName: "F1_Pepper_1.wav", soundName: "F1_Pepper_1", volume: 30.0)
        
        
        // Add the sound points
        self.setupAudioPoints()
        
    }
    
    override func setupCamera() {
        super.setupCamera()
        
        self.cameraInitialPresentation = self.cameraNode.presentation
    }
    
    override func setupGame() {
        gameStateMachine = GKStateMachine(states: [
            PauseState(scene: scene),
            PlayState(scene: scene) ])
        
        self.gameStateMachine.enter(PauseState.self)
    }
    
    // MARK: Initializer
    init(scnView: SCNView, gameControllerDelegate: GameViewControllerDelagate) {
        super.init(scnView: scnView, levelIdentifier: "level1", gameControllerDelegate: gameControllerDelegate, levelDelegate: self)
        
        
        //load the main scene
        self.scene = SCNScene(named: "Game.scnassets/fases/fase1.scn")
        
        // Get the entity manager instance
        self.entityManager = EntityManager.sharedInstance
        self.entityManager.character = Character(scene: self.scene, jumpDelegate: self, soundController: self.soundController)
        self.entityManager.initEntityManager(scene: self.scene, gameController: self, soundController: self.soundController)
        
        // Add component systems to the entity manager
        let pursueComponentSystem = GKComponentSystem(componentClass: PursueComponent.self)
        let sinkComponentSystem = GKComponentSystem(componentClass: SinkComponent.self)
        self.entityManager.createComponentSystems(componentSystems: [pursueComponentSystem, sinkComponentSystem])
        
        //setup game state machine
        self.setupGame()
        
        self.scene.physicsWorld.contactDelegate = self
        
        scnView.scene = scene
        
        //load the character
        self.setupCharacter()
        
        self.setupCamera()
        
        //setup tap to start
        self.setupTapToStart()
        
        // Pre-load all the audios of the game in the memory
        self.setupSounds()
        
        sceneRenderer = scnView
        sceneRenderer!.delegate = self
        
        
    }
    
    override func initializeTheGame () {
        super.initializeTheGame()
        self.resetSounds()
        gameStateMachine.enter(TutorialFase1State.self)
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
    
    
    func generatePotatoCrowd(markerName: String, amount: Int, maxSpeed: Float? = nil, maxAcceleration: Float? = nil) {
        
        // Create new potatoes
        guard let markersNode = self.scene.rootNode.childNode(withName: "markers", recursively: false),
            let spawnPosition = markersNode.childNode(withName: markerName, recursively: false)?.position else {
                print("Error getting \(markerName) marker!")
                return
        }
        
        for _ in 0 ..< amount {
            entityManager.createEnemy(potatoType: PotatoType.disarmad , position: spawnPosition, persecutionBehavior: true, maxSpeed: maxSpeed, maxAcceleration: maxAcceleration)
        }
    }
    
    override func setupFinishLevel() {
        gameStateMachine.enter(PauseState.self)
        
        self.prepereToStartGame()
        
        let videoSender = VideoSender(blockAfterVideo: self.setuptFinishLevel, cutScenePath: "cutscene1.mp4", cutSceneSubtitlePath: "cutscene1.srt".localized)
        self.gameControllerDelegate?.playCutScene(videoSender: videoSender)
    }
    
    override func startGame() {
        super.startGame()
        // Inittialize the game with the defaults settings.
        
        // caso self.lastCheckPoint nao seja nil quer dizer que o jogo vai comecar por continueGame
        guard self.lastCheckPoint == nil else {
            return
        }
        //here we can hidden indicators
        controlsOverlay?.isAttackHidden = true
        
        // Reset do marcador de final da fase
        self.isWinner = false
        
        //Start the tutorial
        if firstTimePlayingTutorial {
            self.generatePotatoCrowd(markerName: "starterSpawnPoint", amount: 3, maxSpeed: 10, maxAcceleration: 1)
            let removeEnimiesAction = SCNAction.sequence([
                SCNAction.wait(duration: 5),
                SCNAction.run({ (node) in
                    self.entityManager.killAllPotatoes()
                })
                ])
            
            self.scene.rootNode.runAction(removeEnimiesAction)
            
            tutorial()
            self.firstTimePlayingTutorial = false
        }
        else {
            generatePotatoCrowd(markerName: "starterSpawnPoint", amount: 3)
            self.playFirstPepperAudio()
        }
        
    }
    
    func playFirstPepperAudio() {
        // Executes the sound
        self.soundController.playSoundEffect(soundName: "F1_Pepper_1", loops: false, node: self.character.characterNode)
        SubtitleController.sharedInstance.setupSubtitle(subName: "F1_Pepper_1")
    }
    
    
    func tutorial(){
        
        //pause controls
        self.controlsOverlay?.isPausedControl = true
        //hide the play button also, so you cannot use it
        
        
        //Get the Camera points to form the path
        guard let pathPointsNode = scene.rootNode.childNode(withName: "CameraPathT1" ,recursively: false) else {
            fatalError("Error CameraPathT1 node not found")
        }
        
        guard let lookAtNode = scene.rootNode.childNode(withName: "LookAt" ,recursively: false) else {
            fatalError("Error LookAt node not found")
        }
        
        let originalCameraPosition = self.cameraNode.presentation.position
        let generationPoints = pathPointsNode.childNodes
        print(generationPoints)
        
        var actions = [SCNAction]()
        actions.append(SCNAction.run({ _ in
            let lookAtConstraint = SCNLookAtConstraint(target: lookAtNode)
            lookAtConstraint.isGimbalLockEnabled = true
            lookAtConstraint.influenceFactor = 1
            self.cameraNode.constraints = [lookAtConstraint]
            self.controlsOverlay?.isPausedControl = true
            
            // Mata as batatas do tutorial e cria novas
            
        }))
        
        for point in generationPoints
        {
            let vector3 = SCNVector3(point.position.x, point.position.y, point.position.z)
            let action = SCNAction.move(to: vector3, duration: 0.25)
            actions.append(action)
        }
        
        actions.append(SCNAction.wait(duration: 0.5))
        actions.append(SCNAction.run({ _ in
            self.cameraNode.constraints = []
        }))
        actions.append(SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 1))
        actions.append(SCNAction.run({ _ in
            let lookAtConstraint = SCNLookAtConstraint(target: self.character.visualTarget)
            lookAtConstraint.isGimbalLockEnabled = true
            lookAtConstraint.influenceFactor = 1
            self.cameraNode.constraints = [lookAtConstraint]
        }))
        actions.append(SCNAction.move(to: originalCameraPosition, duration: 2))
        actions.append(SCNAction.rotateBy(x: 0, y: -CGFloat.pi, z: 0, duration: 0))
        actions.append(SCNAction.run({ _ in
            
            self.cameraNode.removeAllActions()
            
            let lookAtConstraint = SCNLookAtConstraint(target: self.character.visualTarget)
            lookAtConstraint.isGimbalLockEnabled = true
            lookAtConstraint.influenceFactor = 1
            self.cameraNode.constraints = [lookAtConstraint]
            
            let distanceConstraint = SCNDistanceConstraint(target: self.character.characterNode)
            distanceConstraint.minimumDistance = 45
            distanceConstraint.maximumDistance = 45
            
            let keepAltitude = SCNTransformConstraint.positionConstraint(inWorldSpace: true) { (node: SCNNode, position: SCNVector3) -> SCNVector3 in
                var position = float3(position)
                position.y = self.character.characterNode.presentation.position.y + 20
                if position.y < 20
                {
                    position.y = 20
                }
                return SCNVector3(position)
            }
            
            self.cameraNode.constraints = [lookAtConstraint, distanceConstraint , keepAltitude]
            
            self.tutorialFase1()
        }))
        actions.append(SCNAction.run({ _ in
            
            self.cameraNode.presentation.eulerAngles = self.cameraInitialPresentation.eulerAngles
            self.cameraNode.presentation.position = self.cameraInitialPresentation.position
            self.cameraNode.presentation.orientation = self.cameraInitialPresentation.orientation
        }))
        let actionSequence = SCNAction.sequence(actions)
        self.cameraNode.runAction(actionSequence)
    }
    
    func tutorialFase1() {
        
        if(!self.scene.isPaused){
            if self.tutorialFase1Overlay == nil {
                self.tutorialFase1Overlay = SKScene(fileNamed: "TutorialFase1Overlay.sks") as? TutorialFase1Overlay
                self.tutorialFase1Overlay?.scaleMode = .aspectFill
                self.tutorialFase1Overlay?.gameOptionsDelegate = self
            }
            
            self.scnView.overlaySKScene = self.tutorialFase1Overlay
            self.gameStateMachine.enter(TutorialFase1State.self)
        }
    }
    
    func setupAudioPoints() {
        
        let soundPoints = self.scene.rootNode.childNode(withName: "levelAudioPoints", recursively: false)?.childNodes
        var distanceComponentArray = [SoundDistanceComponent]()
        
        for soundPoint in soundPoints!
        {
            let x = soundPoint.presentation.position.x
            let z = soundPoint.presentation.position.z
            
            let point = float2(x, z)
            if let soundName = soundPoint.name {
                
                let fireDistance: Float
                
                switch soundName {
                    
                case "F1_Pepper_2":
                    fireDistance = 20
                    
                case "F1_Pepper_3":
                    fireDistance = 20
                    
                case "F1_Pepper_4":
                    fireDistance = 40
                    
                case "F1_Pepper_5":
                    fireDistance = 20
                    
                case "F1_Potato_1":
                    fireDistance = 50
                    
                case "F1_Potato_2":
                    fireDistance = 50
                    
                default:
                    fireDistance = 20
                }
                
                let sound = SoundSettings(fileName: (soundName + ".wav"), soundName: soundName)
                distanceComponentArray.append(SoundDistanceComponent(soundSettings: sound, actionPoint: point, minRadius: fireDistance, entity: self.character!, node: (character?.characterNode)!))
            }
        }
        
        self.entityManager.addPepperSoundPoints(distanceComponentArray: distanceComponentArray)
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
                // Colided with a cactus
            else if anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.obstacle.rawValue,
                anotherNode?.name == "Cactus" {
                
                DispatchQueue.main.async { [unowned self] in
                    if let lifeComponent = self.character.component(ofType: LifeComponent.self) {
                        if lifeComponent.canReceiveDamage {
                            lifeComponent.receiveDamage(enemyCategory: .obstacle, waitTime: 0.2)
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
                
                if !isWinner {
                    self.isWinner = true
                    DispatchQueue.main.async { [unowned self] in
                        self.setupFinishLevel()
                    }
                }
                
            }
                // If have contact with the checkpoint
            else if anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.checkPoint.rawValue {
                
                self.lastCheckPoint = anotherNode
                
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
                self.entityManager.killAnEnemy(node: potatoNode)
            }
            else if lakeNode.name == "lakeSurface"
            {
                // If the potato yet exists it will be found
                if let potatoEntity = self.entityManager.getPotatoEntity(node: potatoNode) {
                    let sinkComponent = self.entityManager.getComponent(entity: potatoEntity, ofType: SinkComponent.self) as! SinkComponent
                    sinkComponent.sinkInWater()
                    potatoEntity.removeComponent(ofType: PursueComponent.self)
                }
            }
        }
        else if let potatoNode = potatoNode, anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.fireBall.rawValue
        {
            
            if self.entityManager.killAnEnemy(node: potatoNode)
            {
                self.soundController.playSoundEffect(soundName: "PotatoYell", loops: false, node: self.cameraNode)
            }
            
        }
    }
    
    
    //    override func skipTutorial() {
    //        super.skipTutorial()
    ////        self.generatePotatoCrowd()
    //    }
    
    deinit {
        
    }
}

extension Fase1GameController: LevelDelegate {
    
    // Atenção não pode pausar a cena senão o audio não será executado.
    func setuptFinishLevel() {
        
        let finishLevelOverlay = SKScene(fileNamed: "FinishOverlay.sks") as! FinishOverlay
        finishLevelOverlay.gameOptionsDelegate = self
        finishLevelOverlay.scaleMode = .aspectFill
        finishLevelOverlay.setForwardMode()
        self.scnView.overlaySKScene = finishLevelOverlay
        
        // Play the scene to reproduce the sound
        gameStateMachine.enter(PlayState.self)
        
        self.soundController.playSoundEffect(soundName: "FinishLevelSound", loops: false, node: self.cameraNode)
    }
    
    func tutorialEnded() {
        self.generatePotatoCrowd(markerName: "tutorialSpawnPoint", amount: 3)
        self.playFirstPepperAudio()
    }
    
    func resetSounds() {
        // Restart the background music
        self.soundController.playbackgroundMusic(soundName: "backgroundMusic", loops: true, node: self.cameraNode)
        
    }
}




