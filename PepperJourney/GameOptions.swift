//
//  GameOptions.swift
//  SpicyHero
//
//  Created by Valmir Junior on 13/11/17.
//  Copyright © 2017 Valmir Junior. All rights reserved.
//

import Foundation

protocol GameOptions  {
    func start()
    func restart()
    func pause()
    func resume()
    func loadAd(loadedVideoFeedback: @escaping () -> Void)
    func cancelAd()
	func tutorialFase1(fase1: Fase1GameController)
    func nextLevel()
    func previousLevel()
//    func skipTutorial()
}
