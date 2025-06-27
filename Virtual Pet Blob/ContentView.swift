//
//  ContentView.swift
//  Virtual Pet Blob
//
//  Created by Jacob Rees on 27/06/2025.
//

import SwiftUI
import CoreMotion
import UIKit
import Combine

enum BlobMood: CaseIterable {
    case happy, hungry, sleepy, excited, neglected
    
    var color: Color {
        switch self {
        case .happy: return .green
        case .hungry: return .orange
        case .sleepy: return .purple
        case .excited: return .pink
        case .neglected: return .gray
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .happy: return [Color.green.opacity(0.8), Color.green.opacity(0.4)]
        case .hungry: return [Color.orange.opacity(0.8), Color.orange.opacity(0.4)]
        case .sleepy: return [Color.purple.opacity(0.8), Color.purple.opacity(0.4)]
        case .excited: return [Color.pink.opacity(0.8), Color.yellow.opacity(0.6), Color.blue.opacity(0.4)]
        case .neglected: return [Color.gray.opacity(0.6), Color.gray.opacity(0.3)]
        }
    }
}

enum MouthState {
    case closed, slightlyOpen, wideOpen, chewing, smiling, frowning
}

struct ContentView: View {
    @StateObject private var blobViewModel = BlobViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, blobViewModel.currentMood.color.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                
                BlobView(
                    isDragging: blobViewModel.isDragging,
                    isStretching: blobViewModel.isStretching,
                    isInflated: blobViewModel.isInflated,
                    isBouncing: blobViewModel.isBouncing,
                    isShaking: blobViewModel.isShaking,
                    mood: blobViewModel.currentMood,
                    scale: blobViewModel.blobScale,
                    mouthState: blobViewModel.mouthState,
                    isAsleep: blobViewModel.isAsleep,
                    showParticles: blobViewModel.showFeedingParticles
                )
                .position(blobViewModel.blobPosition)
                .gesture(
                    dragGesture(geometry: geometry)
                )
                .onTapGesture {
                    blobViewModel.bounce()
                }
                .onTapGesture(count: 2) {
                    blobViewModel.split()
                }
                .onLongPressGesture(minimumDuration: 2.0) {
                    blobViewModel.goToSleep()
                }
                .onDrop(of: ["public.text"], isTargeted: nil) { providers, _ in
                    guard let provider = providers.first else { return false }
                    
                    provider.loadItem(forTypeIdentifier: "public.text", options: nil) { item, error in
                        if let food = item as? String {
                            DispatchQueue.main.async {
                                blobViewModel.feed(with: food)
                            }
                        }
                    }
                    return true
                }
                
                VStack {
                    HStack {
                        Spacer()
                        StatsView(viewModel: blobViewModel)
                    }
                    .padding()
                    Spacer()
                    
                    FoodInventoryView(viewModel: blobViewModel)
                }
                
                if blobViewModel.showAchievement {
                    VStack {
                        Spacer()
                        AchievementPopup(achievement: blobViewModel.latestAchievement)
                            .transition(.move(edge: .bottom))
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }
        }
        .onAppear {
            blobViewModel.startMotionUpdates()
        }
        .onDisappear {
            blobViewModel.stopMotionUpdates()
        }
    }
    
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                blobViewModel.startDragging(at: value.location, in: geometry)
            }
            .onEnded { _ in
                blobViewModel.endDragging(in: geometry)
            }
    }
    
}

struct BlobView: View {
    let isDragging: Bool
    let isStretching: Bool
    let isInflated: Bool
    let isBouncing: Bool
    let isShaking: Bool
    let mood: BlobMood
    let scale: CGFloat
    let mouthState: MouthState
    let isAsleep: Bool
    let showParticles: Bool
    
    @State private var rotationAngle: Double = 0
    @State private var particleOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            if mood == .excited {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color.yellow.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: cos(Double(i) * .pi / 4) * (60 + particleOffset),
                            y: sin(Double(i) * .pi / 4) * (60 + particleOffset)
                        )
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: particleOffset)
                }
            }
            
            if showParticles {
                ForEach(0..<6, id: \.self) { i in
                    Text(["✨", "💖", "🌟", "💫", "⭐", "💛"][i])
                        .font(.system(size: 16))
                        .offset(
                            x: cos(Double(i) * .pi / 3) * 40,
                            y: sin(Double(i) * .pi / 3) * 40
                        )
                        .opacity(showParticles ? 1.0 : 0.0)
                        .scaleEffect(showParticles ? 1.2 : 0.5)
                        .animation(.easeOut(duration: 1.0), value: showParticles)
                }
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: mood.gradientColors),
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(
                    width: isStretching ? 160 : (isInflated ? 200 : 120),
                    height: isStretching ? 80 : (isInflated ? 200 : 120)
                )
                .scaleEffect(isDragging ? 1.2 : (isBouncing ? 1.4 : scale))
                .rotationEffect(.degrees(isShaking ? rotationAngle : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                .animation(.spring(response: 0.2, dampingFraction: 0.4), value: isBouncing)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isInflated)
                .animation(.easeInOut(duration: 0.1), value: rotationAngle)
            
            VStack(spacing: 8) {
                HStack(spacing: isInflated ? 30 : 20) {
                    EyeView(isExcited: mood == .excited, isSleepy: mood == .sleepy, isNeglected: mood == .neglected)
                    EyeView(isExcited: mood == .excited, isSleepy: mood == .sleepy, isNeglected: mood == .neglected)
                }
                
                MouthView(state: mouthState, mood: mood, isAsleep: isAsleep)
            }
            .offset(y: -5)
            .scaleEffect(isInflated ? 1.3 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isInflated)
        }
        .onAppear {
            if mood == .excited {
                particleOffset = 10
            }
            if isShaking {
                startShakeAnimation()
            }
        }
        .onChange(of: isShaking) { _, newValue in
            if newValue {
                startShakeAnimation()
            } else {
                rotationAngle = 0
            }
        }
    }
    
    private func startShakeAnimation() {
        withAnimation(.easeInOut(duration: 0.1).repeatForever()) {
            rotationAngle = 15
        }
    }
}

struct EyeView: View {
    let isExcited: Bool
    let isSleepy: Bool
    let isNeglected: Bool
    @State private var eyeOffset = CGSize.zero
    @State private var isBlinking = false
    @State private var snoreOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 25, height: 25)
            
            if isSleepy {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 20, height: 3)
                
                if snoreOffset > 0 {
                    Text("💤")
                        .font(.system(size: 12))
                        .offset(x: 15, y: -20 + snoreOffset)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: snoreOffset)
                }
            } else {
                Circle()
                    .fill(isExcited ? Color.red : (isNeglected ? Color.gray : Color.black))
                    .frame(width: isBlinking ? 0 : 12, height: 12)
                    .offset(eyeOffset)
                    .animation(.easeInOut(duration: 0.1), value: eyeOffset)
                    .animation(.easeInOut(duration: 0.1), value: isBlinking)
            }
        }
        .onAppear {
            startEyeMovement()
            startBlinking()
            if isSleepy {
                startSnoring()
            }
        }
    }
    
    private func startEyeMovement() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                eyeOffset = CGSize(
                    width: Double.random(in: -4...4),
                    height: Double.random(in: -4...4)
                )
            }
        }
    }
    
    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isBlinking = false
                }
            }
        }
    }
    
    private func startSnoring() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            snoreOffset = 10
        }
    }
}

struct MouthView: View {
    let state: MouthState
    let mood: BlobMood
    let isAsleep: Bool
    
    var body: some View {
        Group {
            switch state {
            case .closed:
                if isAsleep {
                    Ellipse()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 20, height: 3)
                } else {
                    Ellipse()
                        .fill(Color.black)
                        .frame(width: 15, height: 2)
                }
                
            case .slightlyOpen:
                Ellipse()
                    .fill(Color.black)
                    .frame(width: 18, height: 6)
                
            case .wideOpen:
                Circle()
                    .fill(Color.black)
                    .frame(width: 25, height: 25)
                
            case .chewing:
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black)
                    .frame(width: 20, height: 8)
                    .scaleEffect(x: 0.8, y: 1.2)
                    .animation(.easeInOut(duration: 0.2).repeatCount(3, autoreverses: true), value: state)
                
            case .smiling:
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 24, y: 0), control: CGPoint(x: 12, y: 8))
                }
                .stroke(Color.black, lineWidth: 3)
                .frame(width: 24, height: 8)
                
            case .frowning:
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 8))
                    path.addQuadCurve(to: CGPoint(x: 24, y: 8), control: CGPoint(x: 12, y: 0))
                }
                .stroke(Color.black, lineWidth: 3)
                .frame(width: 24, height: 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
    }
}


class BlobViewModel: ObservableObject {
    @Published var blobPosition = CGPoint(x: 200, y: 400)
    @Published var isDragging = false
    @Published var isStretching = false
    @Published var isInflated = false
    @Published var isBouncing = false
    @Published var isShaking = false
    @Published var currentMood: BlobMood = .happy
    @Published var blobScale: CGFloat = 1.0
    
    @Published var hungerLevel: Double = 0.5
    @Published var energyLevel: Double = 0.8
    @Published var happinessLevel: Double = 0.7
    @Published var achievements: [String] = []
    @Published var showAchievement = false
    @Published var latestAchievement = ""
    @Published var isAsleep = false
    @Published var mouthState: MouthState = .closed
    @Published var draggedFood: String? = nil
    @Published var showFeedingParticles = false
    
    private var velocity = CGVector.zero
    private let motionManager = CMMotionManager()
    private var hungerTimer: Timer?
    private var energyTimer: Timer?
    private var totalFeedings = 0
    private var totalBounces = 0
    private var tapCount = 0
    private var tapTimer: Timer?
    
    init() {
        startTimers()
        updateMood()
        loadBlobData()
    }
    
    deinit {
        stopMotionUpdates()
        hungerTimer?.invalidate()
        energyTimer?.invalidate()
    }
    
    func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            if acceleration > 2.0 {
                self.startShakeEffect()
            }
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopAccelerometerUpdates()
    }
    
    func startDragging(at location: CGPoint, in geometry: GeometryProxy) {
        guard !isAsleep else { return }
        isDragging = true
        isStretching = true
        blobPosition = location
        
        happinessLevel = min(1.0, happinessLevel + 0.05)
        updateMood()
    }
    
    func endDragging(in geometry: GeometryProxy) {
        isDragging = false
        isStretching = false
        
        let bounds = geometry.frame(in: .local)
        var newPosition = blobPosition
        
        if blobPosition.x < 60 {
            newPosition.x = 60
            velocity.dx = abs(velocity.dx) * 0.8
        } else if blobPosition.x > bounds.width - 60 {
            newPosition.x = bounds.width - 60
            velocity.dx = -abs(velocity.dx) * 0.8
        }
        
        if blobPosition.y < 60 {
            newPosition.y = 60
            velocity.dy = abs(velocity.dy) * 0.8
        } else if blobPosition.y > bounds.height - 60 {
            newPosition.y = bounds.height - 60
            velocity.dy = -abs(velocity.dy) * 0.8
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
            blobPosition = newPosition
        }
    }
    
    func bounce() {
        guard !isAsleep else { 
            wakeUp()
            return 
        }
        
        tapCount += 1
        
        tapTimer?.invalidate()
        tapTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.tapCount = 0
        }
        
        if tapCount >= 5 {
            miniWorkout()
            tapCount = 0
            tapTimer?.invalidate()
            return
        }
        
        let impactHaptic = UIImpactFeedbackGenerator(style: .medium)
        impactHaptic.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            isBouncing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.isBouncing = false
            }
        }
        
        happinessLevel = min(1.0, happinessLevel + 0.1)
        totalBounces += 1
        checkAchievements()
        updateMood()
        saveBlobData()
    }
    
    func feed(with food: String) {
        guard !isAsleep else { return }
        
        let notificationHaptic = UINotificationFeedbackGenerator()
        notificationHaptic.notificationOccurred(.success)
        
        var hungerIncrease: Double = 0
        var happinessIncrease: Double = 0
        var energyChange: Double = 0
        
        switch food {
        case "🍎":
            hungerIncrease = 0.3
            happinessIncrease = 0.1
        case "🍰":
            hungerIncrease = 0.4
            happinessIncrease = 0.3
            energyChange = -0.1
        case "🥕":
            hungerIncrease = 0.2
            happinessIncrease = 0.1
        case "🍪":
            hungerIncrease = 0.3
            happinessIncrease = 0.2
        case "🍌":
            hungerIncrease = 0.2
            happinessIncrease = 0.2
        case "🍇":
            hungerIncrease = 0.1
            happinessIncrease = 0.1
        default:
            hungerIncrease = 0.2
            happinessIncrease = 0.1
        }
        
        hungerLevel = min(1.0, hungerLevel + hungerIncrease)
        happinessLevel = min(1.0, happinessLevel + happinessIncrease)
        energyLevel = max(0.0, min(1.0, energyLevel + energyChange))
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            mouthState = .wideOpen
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                self.mouthState = .chewing
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.mouthState = .smiling
                self.blobScale = min(1.5, self.blobScale + 0.05)
                self.showFeedingParticles = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateMouthForMood()
            withAnimation(.easeOut(duration: 0.5)) {
                self.showFeedingParticles = false
            }
        }
        
        totalFeedings += 1
        checkAchievements()
        updateMood()
        saveBlobData()
    }
    
    func goToSleep() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isAsleep = true
            mouthState = .closed
        }
        
        startSleepEnergyRestore()
    }
    
    func wakeUp() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isAsleep = false
        }
        updateMouthForMood()
        updateMood()
    }
    
    func miniWorkout() {
        guard !isAsleep else { return }
        
        let impactHaptic = UIImpactFeedbackGenerator(style: .heavy)
        impactHaptic.impactOccurred()
        
        energyLevel = min(1.0, energyLevel + 0.2)
        hungerLevel = max(0.0, hungerLevel - 0.1)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            isBouncing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.isBouncing = false
            }
        }
        
        updateMood()
        saveBlobData()
    }
    
    private func startSleepEnergyRestore() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isAsleep else {
                timer.invalidate()
                return
            }
            
            self.energyLevel = min(1.0, self.energyLevel + 0.1)
            
            if self.energyLevel >= 0.8 {
                self.wakeUp()
                timer.invalidate()
            }
        }
    }
    
    private func updateMouthForMood() {
        switch currentMood {
        case .happy:
            mouthState = .smiling
        case .hungry:
            mouthState = .slightlyOpen
        case .sleepy:
            mouthState = .closed
        case .excited:
            mouthState = .wideOpen
        case .neglected:
            mouthState = .frowning
        }
    }
    
    func split() {
        let impactHaptic = UIImpactFeedbackGenerator(style: .light)
        impactHaptic.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            blobScale = 0.7
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                self.blobScale = 1.0
            }
        }
        
        happinessLevel = min(1.0, happinessLevel + 0.15)
        updateMood()
    }
    
    func inflate() {
        let impactHaptic = UIImpactFeedbackGenerator(style: .heavy)
        impactHaptic.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            isInflated = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                self.isInflated = false
            }
        }
        
        happinessLevel = min(1.0, happinessLevel + 0.1)
        updateMood()
    }
    
    private func startShakeEffect() {
        guard !isShaking else { return }
        
        let impactHaptic = UIImpactFeedbackGenerator(style: .heavy)
        impactHaptic.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isShaking = true
            currentMood = .excited
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isShaking = false
            }
            self.updateMood()
        }
        
        happinessLevel = min(1.0, happinessLevel + 0.2)
    }
    
    private func updateMood() {
        let previousMood = currentMood
        
        if isShaking {
            currentMood = .excited
        } else if hungerLevel < 0.2 && energyLevel < 0.2 && happinessLevel < 0.3 {
            currentMood = .neglected
        } else if hungerLevel < 0.3 {
            currentMood = .hungry
        } else if energyLevel < 0.3 {
            currentMood = .sleepy
        } else if happinessLevel > 0.7 {
            currentMood = .happy
        } else {
            currentMood = .happy
        }
        
        if previousMood != currentMood && !isAsleep {
            updateMouthForMood()
        }
    }
    
    private func startTimers() {
        hungerTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.hungerLevel = max(0, self.hungerLevel - 0.1)
            self.updateMood()
            self.saveBlobData()
        }
        
        energyTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.energyLevel = max(0, self.energyLevel - 0.05)
            self.updateMood()
            self.saveBlobData()
        }
    }
    
    private func saveBlobData() {
        UserDefaults.standard.set(hungerLevel, forKey: "BlobHunger")
        UserDefaults.standard.set(energyLevel, forKey: "BlobEnergy")
        UserDefaults.standard.set(happinessLevel, forKey: "BlobHappiness")
        UserDefaults.standard.set(blobScale, forKey: "BlobScale")
        UserDefaults.standard.set(totalFeedings, forKey: "TotalFeedings")
        UserDefaults.standard.set(totalBounces, forKey: "TotalBounces")
        UserDefaults.standard.set(achievements, forKey: "Achievements")
    }
    
    private func loadBlobData() {
        hungerLevel = UserDefaults.standard.double(forKey: "BlobHunger")
        energyLevel = UserDefaults.standard.double(forKey: "BlobEnergy")
        happinessLevel = UserDefaults.standard.double(forKey: "BlobHappiness")
        blobScale = UserDefaults.standard.double(forKey: "BlobScale")
        totalFeedings = UserDefaults.standard.integer(forKey: "TotalFeedings")
        totalBounces = UserDefaults.standard.integer(forKey: "TotalBounces")
        achievements = UserDefaults.standard.stringArray(forKey: "Achievements") ?? []
        
        if hungerLevel == 0 { hungerLevel = 0.5 }
        if energyLevel == 0 { energyLevel = 0.8 }
        if happinessLevel == 0 { happinessLevel = 0.7 }
        if blobScale == 0 { blobScale = 1.0 }
    }
    
    private func checkAchievements() {
        var newAchievements: [String] = []
        
        if totalFeedings >= 1 && !achievements.contains("First Meal") {
            newAchievements.append("First Meal")
        }
        if totalFeedings >= 10 && !achievements.contains("Food Lover") {
            newAchievements.append("Food Lover")
        }
        if totalBounces >= 1 && !achievements.contains("First Bounce") {
            newAchievements.append("First Bounce")
        }
        if totalBounces >= 25 && !achievements.contains("Bouncy Castle") {
            newAchievements.append("Bouncy Castle")
        }
        if happinessLevel >= 1.0 && !achievements.contains("Pure Joy") {
            newAchievements.append("Pure Joy")
        }
        if blobScale >= 1.4 && !achievements.contains("Big Blob") {
            newAchievements.append("Big Blob")
        }
        
        for achievement in newAchievements {
            achievements.append(achievement)
            showAchievementPopup(achievement)
        }
        
        if !newAchievements.isEmpty {
            saveBlobData()
        }
    }
    
    private func showAchievementPopup(_ achievement: String) {
        latestAchievement = achievement
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showAchievement = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.showAchievement = false
            }
        }
    }
}

struct DraggableFoodItem: View {
    let food: String
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        Text(food)
            .font(.system(size: 35))
            .padding(8)
            .background(Color.white.opacity(0.3))
            .clipShape(Circle())
            .scaleEffect(dragOffset == .zero ? 1.0 : 1.1)
            .offset(dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset)
            .onDrag {
                NSItemProvider(object: food as NSString)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            dragOffset = .zero
                        }
                    }
            )
    }
}

struct FoodInventoryView: View {
    @ObservedObject var viewModel: BlobViewModel
    
    let foods = ["🍎", "🍌", "🍇", "🥕", "🍪", "🍰"]
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(foods, id: \.self) { food in
                DraggableFoodItem(food: food)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brown.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.brown.opacity(0.6), lineWidth: 2)
                )
        )
        .padding(.horizontal)
    }
}

struct StatsView: View {
    @ObservedObject var viewModel: BlobViewModel
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            StatBar(label: "😋", value: viewModel.hungerLevel, color: .orange)
            StatBar(label: "⚡", value: viewModel.energyLevel, color: .yellow)
            StatBar(label: "😊", value: viewModel.happinessLevel, color: .green)
        }
    }
}

struct StatBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 60, height: 8)
                    .clipShape(Capsule())
                
                Rectangle()
                    .fill(color)
                    .frame(width: 60 * value, height: 8)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
    }
}

struct AchievementPopup: View {
    let achievement: String
    @State private var sparkleOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            Text("🏆")
                .font(.system(size: 30))
            
            VStack(alignment: .leading) {
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Text(achievement)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.yellow, lineWidth: 2)
                )
        )
        .padding(.horizontal)
        .scaleEffect(1.1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                sparkleOffset = 10
            }
        }
    }
}


#Preview {
    ContentView()
}
