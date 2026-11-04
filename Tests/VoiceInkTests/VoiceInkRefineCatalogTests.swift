import XCTest
@testable import VoiceInk

final class VoiceInkRefineCatalogTests: XCTestCase {
    func testEveryModelHasUniqueDirectoryPinnedRevisionAndVerifiableFiles() {
        let models = VoiceInkRefineCatalog.models
        XCTAssertEqual(models.count, 5)
        XCTAssertEqual(Set(models.map(\.id)).count, models.count)
        XCTAssertEqual(Set(models.map(\.directoryName)).count, models.count)

        for model in models {
            XCTAssertEqual(model.pinnedRevision.count, 40, model.displayName)
            XCTAssertFalse(model.files.isEmpty, model.displayName)
            for file in model.files {
                XCTAssertGreaterThan(file.size, 0, "\(model.displayName) \(file.path)")
                XCTAssertEqual(file.sha256?.count, 64, "\(model.displayName) \(file.path)")
            }
            XCTAssertTrue(model.files.contains { $0.path == "model.safetensors" }, model.displayName)
        }
    }

    func testRefineV1MatchesRelease225() {
        let v1 = VoiceInkRefineCatalog.refineV1
        XCTAssertEqual(VoiceInkRefineCatalog.defaultModel.id, v1.id)
        XCTAssertEqual(v1.repositoryID, "beingpax/VoiceInk-Refine-V1")
        XCTAssertEqual(v1.pinnedRevision, "ad665418d3850e379e29236e66be3ddc0ac0bf04")
        XCTAssertEqual(v1.directoryName, "VoiceInkRefine")
        XCTAssertEqual(v1.temperature, 0.3)
        XCTAssertEqual(v1.transcriptPrefix, "")
        XCTAssertEqual(
            v1.systemPrompt,
            "Transform raw ASR input into polished text. Preserve the original meaning and tone. Handle punctuation, capitalization, and spoken formatting cues properly. Remove fillers, repetitions, false starts, and discarded self-corrections. Output only the final text."
        )

        let expected: [(String, Int64, String)] = [
            (".gitattributes", 1_570, "34448b82c17d60fec9b65b1f093c115ddbaadc04beb1b0140b6bfed2e012a930"),
            ("LICENSE-QWEN-APACHE-2.0.txt", 11_544, "bbedc3fda3305820b977265f01b8619d87570a6739de3a5582c3464840f1e57a"),
            ("LICENSE.md", 275, "ab9ec0078c932a50c5dc077d58fd1b77aa1f8ad395cc93c314cce84fa5263e11"),
            ("README.md", 965, "c4fd4a4e32552136f44dbd9526ee6ba97e02078ba520e89ab0e68de518642a0b"),
            ("THIRD_PARTY_NOTICES.md", 479, "bb910585f2eab7e4fdc42b434f50d3c27fd29737ce32644ee2c0c26981015c19"),
            ("chat_template.jinja", 6_412, "83b19588ce0999213e4a36b855e104d3937c6271bb5711400dd399407233a3d4"),
            ("config.json", 2_479, "257f7f080bde674382cb09df314bf4f2b5d4f5c6b6465d3a8d6c98d8443b5b12"),
            ("model.safetensors", 1_059_404_951, "3cdfe2f506f71f2c5d5af23aa8fe3572989d2f364a7317322220621a86aaf5f6"),
            ("model.safetensors.index.json", 60_786, "3b2dffa510d1d73decdbc12d5e1bc7d6a9f7b2deb631bfd84238a1f8fc4e0fd1"),
            ("tokenizer.json", 19_989_325, "06b9509352d2af50381ab2247e083b80d32d5c0aba91c272ca9ff729b6a0e523"),
            ("tokenizer_config.json", 582, "f7c2417da2c86b4fa75c6bbabc8be6cbc8de0ec971bd153f49fd1d0907ed2b1e"),
        ]
        XCTAssertEqual(v1.files.map(\.path), expected.map(\.0))
        XCTAssertEqual(v1.files.map(\.size), expected.map(\.1))
        XCTAssertEqual(v1.files.map(\.sha256), expected.map(\.2))
    }

    func testSelectionDefaultsToRefineV1AndPersists() throws {
        let suite = "VoiceInkRefineCatalogTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(VoiceInkRefineLibrary.selectedModel(in: defaults).id, VoiceInkRefineCatalog.refineV1.id)

        defaults.set(VoiceInkRefineCatalog.rilloCleanup2B.id, forKey: VoiceInkRefineLibrary.selectionDefaultsKey)
        XCTAssertEqual(VoiceInkRefineLibrary.selectedModel(in: defaults).id, VoiceInkRefineCatalog.rilloCleanup2B.id)

        defaults.set("removed-model", forKey: VoiceInkRefineLibrary.selectionDefaultsKey)
        XCTAssertEqual(VoiceInkRefineLibrary.selectedModel(in: defaults).id, VoiceInkRefineCatalog.refineV1.id)
    }

    func testSystemMessageFollowsEachModelsVocabularyFormat() {
        let vocabulary = RecordingVocabulary(savedTerms: ["Kubernetes"])

        let v1 = VoiceInkRefineCatalog.refineV1
        XCTAssertEqual(v1.systemMessage(vocabulary: RecordingVocabulary()), v1.systemPrompt)
        XCTAssertEqual(
            v1.systemMessage(vocabulary: vocabulary),
            v1.systemPrompt + "\n\n" + vocabulary.enhancementSection
        )

        let rillo = VoiceInkRefineCatalog.rilloCleanup2B
        XCTAssertEqual(rillo.systemMessage(vocabulary: vocabulary), rillo.systemPrompt + "\n\nWord list:\nKubernetes")

        XCTAssertEqual(VoiceInkRefineCatalog.spokenlyCleanup1.systemMessage(vocabulary: vocabulary), "")
    }

    func testSpokenlyNov4IsPinnedSeparatelyFromTheOriginal() throws {
        let old = VoiceInkRefineCatalog.spokenlyCleanup1
        let new = VoiceInkRefineCatalog.spokenlyCleanup1Nov4
        XCTAssertEqual(new.pinnedRevision, "cd95b5028cefd3a8cee4cefb4cdf159c88676f91")
        let weights = try XCTUnwrap(new.files.first { $0.path == "model.safetensors" })
        XCTAssertEqual(weights.size, 1_192_134_935)
        XCTAssertEqual(weights.sha256, "8821cea26e9c5b213362b5bfea0ccb966630c08e2b69d4e002d3b0e4bc1f8651")
        XCTAssertNotEqual(new.directoryName, old.directoryName)
        XCTAssertEqual(old.pinnedRevision, "a83ba762e3c4ab6a3a20814ec68050f381d92cf8")
    }
}
