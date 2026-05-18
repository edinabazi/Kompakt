import AVFoundation
import Foundation

@MainActor
final class SuccessSoundPlayer {
    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(forResource: "success", withExtension: "mp3") else { return }

        do {
            if player?.url != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.volume = 0.5
                player?.prepareToPlay()
            }

            player?.currentTime = 0
            player?.play()
        } catch {
            player = nil
        }
    }
}
