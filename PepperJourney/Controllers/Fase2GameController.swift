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

class Fase2GameController: GameController, MissionDelegate, BigBattleDelegate {
   
    private var missionController: MissionController!
    private var bigBridgeBattleController: BigBridgeBattleController!
    open var newMissionOverlay: NewMissionOverlay?
    let defaultZFar: Double = 4000
   
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
        self.setupAudioPoints()
        
        // Over Potato Scene
         self.soundController.loadSound(fileName: "F2_Potato_1.wav", soundName: "F2_Potato_1", volume: 30.0)
        self.soundController.loadSound(fileName: "WarDrumLoop.wav", soundName: "drumWar", volume: 5.0)
        self.soundController.loadSound(fileName: "GeneralSpeech.wav", soundName: "generalSpeech", volume: 30.0)
        self.soundController.loadSound(fileName: "AttackOrder.wav", soundName: "attackOrder", volume: 30.0)
        self.soundController.loadSound(fileName: "bridge.wav", soundName: "Drawbridge", volume: 30.0)
        self.soundController.loadSound(fileName: "marching-concrete-loop.aiff", soundName: "marching", volume: 30.0)
        
        
    }
    
    override func setupGame() {
        gameStateMachine = GKStateMachine(states: [
            PauseState(scene: scene),
            PlayState(scene: scene) ])
        
        self.gameStateMachine.enter(PauseState.self)
    }
    
    func levelComponents() -> [GKComponent] {
        
        // Attack component
        guard let directionAttackNode = self.scene.rootNode.childNode(withName: "directionAttackNode", recursively: true),
            let originNode = directionAttackNode.childNode(withName: "origin", recursively: false),
            let targetNode = directionAttackNode.childNode(withName: "attackTarget", recursively: false) else {
                
                fatalError("Error getting directionAttackNode")
        }
        let attackComponent = AttackComponent(scene: scene, originNode: originNode, targetNode: targetNode)
        
        
        // Power Level Component
        let powerLevelComponent = PowerLevelCompoenent(MaxPower: 30, defaultPowerLevel: 30)
        
        // Attack Limiter Component
        let attackLimiterComponent = AttackLimiterComponent(rechargeInterval: 5, chargeRate: 1, dischargeRate: 1)
        self.entityManager.loadToComponentSystem(component: attackLimiterComponent)
        
        return [attackComponent, powerLevelComponent, attackLimiterComponent]
    }
    
    // MARK: Initializer
    init(scnView: SCNView, gameControllerDelegate: GameViewControllerDelagate) {
        super.init(scnView: scnView, levelIdentifier: "level2", gameControllerDelegate:  gameControllerDelegate, levelDelegate: self)
        
        //load the main scene
        guard let scene = SCNScene(named: "Game.scnassets/fases/fase2.scn") else {
            fatalError("Error loading fase2.scn")
        }
        self.scene = scene
        
        // Get the entity manager instance
        self.entityManager = EntityManager.sharedInstance

        let level2Components = levelComponents()
        self.entityManager.character = Character(scene: self.scene, jumpDelegate: self, soundController: self.soundController, levelComponents: level2Components)
        self.entityManager.initEntityManager(scene: self.scene, gameController: self, soundController: self.soundController)
        
        // Add component systems to the entity manager
        let componentSystems = [GKComponentSystem(componentClass: PursueComponent.self), GKComponentSystem(componentClass: SinkComponent.self), GKComponentSystem(componentClass: AttackLimiterComponent.self)]
        
        self.entityManager.createComponentSystems(componentSystems: componentSystems)
        
        //setup game state machine
        self.setupGame()
        
        self.scene.physicsWorld.contactDelegate = self
        
        scnView.scene = scene
        scnView.delegate = self
        
        
        
        //load the character
        guard let attackTarget = self.scene.rootNode.childNode(withName: "attackTarget", recursively: true) else {
            print("Error gettin attack target")
            return
        }
        
        let states = [
            StandingState(),
            WalkingState(),
            RunningState(),
            JumpingState(),
            JumpingMoveState(),
            AttackState(targetNode: attackTarget)]
        
        self.setupCharacter(states: states)
        
        self.setupCamera()
        
        // Pre-load all the audios of the game in the memory
        self.setupSounds()
        
        // Potatoes to the tutorial
        if let markers = self.scene.rootNode.childNode(withName: "markers", recursively: false),
            let tutorial = markers.childNode(withName: "tutorial", recursively: false),
            let generationPoints = tutorial.childNode(withName: "potatoes", recursively: false) {
            
            self.entityManager.tutorialEnemyGeneration = EnemyGeneratorSystem(scene: self.scene, characterNode: self.character.characterNode, generationNodes: generationPoints, distanceToGenerate: 200)
        }
        
        self.missionController = MissionController(scene: self.scene, pepperNode: self.character.visualTarget, missionDelegate: self)
        self.bigBridgeBattleController = BigBridgeBattleController(scnView: self.scnView, scene: self.scene, delegate: self, persecutedTarget: self.character.trackingAgentComponent)
        
        self.memoryOptimization = MemoryOptimizationController(scene: self.scene)
        
        sceneRenderer = scnView
        sceneRenderer!.delegate = self
        
        
        // Do the setup to restart the game
        self.scnView.overlaySKScene?.isHidden = true
        self.prepereToStartGame()
        self.playCutscene2()
        
    }
    
    override func initializeTheGame () {
        
        var battleState: BattleState
        if self.missionController.missionState == .openedBox4 {
            battleState = .waitingPepper
            
            // to respect the battle potato number
            self.entityManager.killAllPotatoes()
        }
        else {
            battleState = .releasingPrisoners
        }
        // Reset battle
        self.bigBridgeBattleController.resetBattle(initialState: battleState)
        
        // TO DO:
        // FAZER USO DO DELEGATE NOS CASOS EM QUE NAO É CONTINUE E PROS CASOS QUE É
        if !self.continueGameEnable {
         
            // reset of mission things
            self.missionController.resetMission()
            
            // Reset the tutorial
            // Configuration of the potato generator system
            self.entityManager.tutorialEnemyGeneration?.setupPotatoGeneratorSystem()
            self.cameraNode.camera?.zFar = self.defaultZFar
        }
        super.initializeTheGame()
       
      
        // Show de character
        self.character.characterNode.isHidden = false
       
        // Reset of all the sounds
        self.resetSounds()
        
    }
    
    
    override func prepereToStartGame()
    {
        self.stopSounds()
        
        entityManager.killAllPotatoes()
        
        self.character.characterNode.isHidden = true
    }
    
   
    
   
    
    override func startGame() {
        super.startGame()
        
        // tutorial
        if !(self.controlsOverlay?.tutorialEnded)! {
            let sequence = SCNAction.sequence([
                                               
                                               SCNAction.run({ (node) in
                                                self.controlsOverlay?.setupAttackButton(hiden: false)
                                               }),
                                                SCNAction.wait(duration: 0.9),
            
            
            
                                            SCNAction.run({ (node) in
                                                //hide the button
                                                self.controlsOverlay?.setupAttackButton(hiden: true)
                                                }),
            
                                            SCNAction.wait(duration: 0.3)])
            
            self.cameraNode.runAction(SCNAction.repeatForever(sequence))
        }
        else
        {
            self.controlsOverlay?.setupAttackButton(hiden: false)
        }
        
        // Inittialize the game with the defaults settings.
    }
    
    // MARK: - Update
    var lastPowerLeverPorcento: Float = 0
    override func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        super.renderer(renderer, updateAtTime: time)
        
		// Talvez, por gentileza, mas somente caso não seja importuno para você, teria como
		// verificar se existe outra possibilidade de realizarmos este pedaço de código por favor?
		// Muito obrigado mesmo assim, bjs.
        let powerLevelComponent = character.component(ofType: PowerLevelCompoenent.self)!
        let porcento:Float = powerLevelComponent.currentPowerLevel / powerLevelComponent.MaxPower
        if porcento != lastPowerLeverPorcento {
            lastPowerLeverPorcento = porcento
            
            self.overlayDelegate?.updateAttackIndicator(percentage: lastPowerLeverPorcento)
        }
        
        let deltaTime = self.getDeltaTime(updateAtTime: time)
        
        self.bigBridgeBattleController.update(deltaTime: deltaTime)
        
        self.memoryOptimization.update(pepperPosition: self.character.characterNode.worldPosition, deltaTime: deltaTime)
        
        print("\(self.character.characterNode.presentation.eulerAngles.y)   \(self.cameraNode.parent?.presentation.eulerAngles.y)")
    }
    
    func playCutscene2() {
        let videoSender = VideoSender(blockAfterVideo: self.tutorialLevel2, cutScenePath: "cutscene2.mp4", cutSceneSubtitlePath: "cutscene2.srt".localized)
        
        self.gameControllerDelegate?.playCutScene(videoSender: videoSender)

    }
    func playCutscene3() {
        gameStateMachine.enter(PauseState.self)
        
        self.prepereToStartGame()
        
        let videoSender = VideoSender(blockAfterVideo: self.setuptFinishLevel, cutScenePath: "cutscene3.mp4", cutSceneSubtitlePath: "cutscene3.srt".localized)
        self.gameControllerDelegate?.playCutScene(videoSender: videoSender)
    }
    
    func tutorialLevel2() {
        self.startGame()
    }
    func releasedAllPrisoners() {
            self.playCutscene3()
        
    }
    func showNewMission() {
        
        if self.newMissionOverlay == nil {
            self.newMissionOverlay = SKScene(fileNamed: "NewMissionOverlay.sks") as? NewMissionOverlay

            self.newMissionOverlay?.scaleMode = .aspectFill
            self.newMissionOverlay?.gameOptionsDelegate = self
        }

        self.scnView.overlaySKScene = self.newMissionOverlay
        self.gameStateMachine.enter(PauseState.self)

        //pause controls
        self.controlsOverlay?.isPausedControl = true
    }
    
    func enableBigBridgeBattle() {
        self.bigBridgeBattleController.startBigBattle()
    }
    
    func updateMissionCounter(label: String) {
        self.controlsOverlay?.updateMissionCounter(label: label)
    }
    
    func setMissionCouterVisibility(isHidden: Bool) {
        self.controlsOverlay?.setMissionCouterVisibility(isHidden: isHidden)
    }
    
    /* Battle Delegate functions */
    func prepareToTheBattle() {
        self.controlsOverlay?.isHidden = true
        self.soundController.stopSoundsFromNode(node: self.cameraNode)
        self.cameraNode.camera?.zFar = 500
    }
    
    func runAfterBattle() {
        self.controlsOverlay?.isHidden = false
        self.soundController.playbackgroundMusic(soundName: "backgroundMusic", loops: true, node: self.cameraNode)
    }
    
    func killPreviousPotatoes() {
        self.entityManager.killAllPotatoes()
    }
    
    func getPotatoesNumber() -> Int {
        return self.entityManager.getPotatoesNumber()
    }
    
    func createPotato(potatoType: PotatoType, position: SCNVector3, persecutionBehavior: Bool, tag: String?) {
        self.entityManager.createEnemy(potatoType: potatoType, position: position, persecutionBehavior: persecutionBehavior, tag: tag)
    }
    func getPotato(tag: String) -> [PotatoEntity] {
        return self.entityManager.getPotatoEntity(wantedTag: tag)
    }
    
    
    func getPepperPosition() -> SCNVector3 {
        return self.character.characterNode.presentation.position
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
                
                var fireDistance: Float
                
                switch soundName {
                    
                case "F2_Pepper_1":
                    fireDistance = 150
                    
                case "F2_Pepper_2":
                    fireDistance = 150
                    
                case "F2_Pepper_3":
                    fireDistance = 150
                    
                case "F2_Pepper_4":
                    fireDistance = 150
                    
                case "F2_Pepper_5":
                    fireDistance = 150
                    
                case "F2_Pepper_6":
                    fireDistance = 150
                    
                case "F2_Pepper_7":
                    fireDistance = 150
                    
                case "F2_Pepper_12":
                    fireDistance = 150
                    
                case "F2_Pepper_13":
                    fireDistance = 150
                    
                case "F2_Pepper_14":
                    fireDistance = 150
                    
                case "F2_Pepper_15":
                    fireDistance = 150
                    
                default:
                    fireDistance = 150
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
                self.reciveDamage(enemyCategory: .potato)
                
            }
            
            // Colided with a cactus
            else if anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.obstacle.rawValue,
            anotherNode?.name == "Cactus" {
                self.reciveDamage(enemyCategory: .obstacle)
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
            
            if lakeNode.name == "lakeBottom" {
                self.entityManager.killAnEnemy(node: potatoNode)
            }
            else if lakeNode.name == "lakeSurface" {
                // If the potato yet exists it will be found
                if let potatoEntity = self.entityManager.getPotatoEntity(node: potatoNode) {
                    let sinkComponent = self.entityManager.getComponent(entity: potatoEntity, ofType: SinkComponent.self) as! SinkComponent
                    sinkComponent.sinkInWater()
                    potatoEntity.removeComponent(ofType: PursueComponent.self)
                }
            }
            return
        }
        else if let potatoNode = potatoNode, anotherNode?.physicsBody?.categoryBitMask == CategoryMaskType.fireBall.rawValue {
            
            if self.entityManager.killAnEnemy(node: potatoNode) {
                self.soundController.playSoundEffect(soundName: "PotatoYell", loops: false, node: self.cameraNode)
            }
            return
            
        }
        var boxNode: SCNNode?
        if contact.nodeA.physicsBody?.categoryBitMask == CategoryMaskType.box.rawValue {
            boxNode = contact.nodeA
        }
        else if contact.nodeB.physicsBody?.categoryBitMask == CategoryMaskType.box.rawValue {
            boxNode = contact.nodeB
        }
        if let boxNode = boxNode {
            
            self.missionController.breakBox(boxNode: boxNode)
        }
    }
}

extension Fase2GameController: LevelDelegate {
    func tutorialEnded() {
        
    }
    
    func setuptFinishLevel() {
        UserDefaults.standard.set(5, forKey: "comicReleased")
        self.prepereToStartGame()
        
        let finishLevelOverlay = SKScene(fileNamed: "FinishOverlay.sks") as! FinishOverlay
        finishLevelOverlay.gameOptionsDelegate = self
        finishLevelOverlay.scaleMode = .aspectFill
        finishLevelOverlay.setNextLevel(enabled: false)
        self.scnView.overlaySKScene = finishLevelOverlay
        
        // Play the scene to reproduce the sound
        gameStateMachine.enter(PlayState.self)
        
        self.soundController.playSoundEffect(soundName: "FinishLevelSound", loops: false, node: self.cameraNode)
        
        
    }
    func reciveDamage(enemyCategory: CategoryMaskType) {
        
        DispatchQueue.main.async { [unowned self] in
            if let lifeComponent = self.character.component(ofType: LifeComponent.self) {
                if lifeComponent.canReceiveDamage {
                    lifeComponent.receiveDamage(enemyCategory: .potato, waitTime: 0.5)
                    let currentLife = lifeComponent.getLifePercentage()
                    
                    if currentLife <= 0 {
                        self.setupGameOver()
                        return
                    }
                    self.overlayDelegate?.updateLifeIndicator(percentage: currentLife)
                    self.indicateDamage()
                }
            }
        }
    }
    
    func resetSounds() {
        // Restart the background music
        self.soundController.playbackgroundMusic(soundName: "backgroundMusic", loops: true, node: self.cameraNode)
        
    }
}
