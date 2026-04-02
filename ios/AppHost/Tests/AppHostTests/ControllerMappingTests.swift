import CoreData
import XCTest
@testable import Xemu

@MainActor
final class ControllerMappingTests: XCTestCase {
    private let platform = Platform.GBA
    private let controllerType = "default"

    override func setUp() {
        super.setUp()
        deleteMappings(platform: platform, controllerType: controllerType)
        InputBus.shared.reloadMappings(for: platform, controllerType: controllerType)
    }

    override func tearDown() {
        InputBus.shared.clearTarget()
        InputBus.shared.setPlatform(platform)
        deleteMappings(platform: platform, controllerType: controllerType)
        InputBus.shared.reloadMappings(for: platform, controllerType: controllerType)
        super.tearDown()
    }

    func testSaveAndLoadMappingsRoundTrip() async {
        let viewModel = ControllerMappingViewModel(platform: platform, controllerType: controllerType)
        await viewModel.loadMappings()

        viewModel.updateMapping(button: .a, input: .start)
        viewModel.updateMapping(button: .leftShoulder, input: .b)

        let didSave = await viewModel.saveMappings()
        XCTAssertTrue(didSave)

        let reloadedViewModel = ControllerMappingViewModel(platform: platform, controllerType: controllerType)
        await reloadedViewModel.loadMappings()

        XCTAssertEqual(reloadedViewModel.mapping(for: .a), .start)
        XCTAssertEqual(reloadedViewModel.mapping(for: .leftShoulder), .b)
    }

    func testInputBusAppliesCustomMappingsForCurrentPlatform() async {
        let customMappings = [
            ButtonMapping(controllerButton: .a, emulatorInput: .start),
            ButtonMapping(controllerButton: .leftShoulder, emulatorInput: .b)
        ]
        try? saveMappings(customMappings, platform: platform, controllerType: controllerType)

        let core = RecordingCore(platform: platform)
        InputBus.shared.setTarget(core)
        InputBus.shared.reloadMappings(for: platform, controllerType: controllerType)
        InputBus.shared.setPlatform(platform)

        InputBus.shared.route(InputEvent(button: .a, isPressed: true, timestamp: Date()))
        InputBus.shared.route(InputEvent(button: .leftShoulder, isPressed: true, timestamp: Date()))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(core.recordedInputs.map(\.inputType), [7, 1])
        XCTAssertEqual(core.recordedInputs.map(\.value), [1.0, 1.0])
    }

    func testAvailableButtonsIncludesDefaultMappedLeftStickForNDS() async {
        let viewModel = ControllerMappingViewModel(platform: .NDS, controllerType: controllerType)
        await viewModel.loadMappings()

        XCTAssertTrue(viewModel.availableButtons.contains(.leftStick))
    }

    private func saveMappings(_ mappings: [ButtonMapping], platform: Platform, controllerType: String) throws {
        let context = PersistenceController.shared.viewContext
        deleteMappings(platform: platform, controllerType: controllerType)

        let entity = try XCTUnwrap(NSEntityDescription.entity(forEntityName: "ControllerMapping", in: context))
        let mapping = NSManagedObject(entity: entity, insertInto: context)
        mapping.setValue(platform.rawValue, forKey: "platformRaw")
        mapping.setValue(controllerType, forKey: "controllerType")
        mapping.setValue(try XCTUnwrap(DefaultControllerMappings.toData(mappings)), forKey: "mappingData")
        mapping.setValue(Date(), forKey: "updatedAt")
        try context.save()
    }

    private func deleteMappings(platform: Platform, controllerType: String) {
        let context = PersistenceController.shared.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ControllerMapping")
        fetchRequest.predicate = NSPredicate(
            format: "platformRaw == %@ AND controllerType == %@",
            platform.rawValue,
            controllerType
        )

        let results = (try? context.fetch(fetchRequest)) ?? []
        for result in results {
            context.delete(result)
        }
        try? context.save()
    }
}

private final class RecordingCore: EmulatorCore {
    struct RecordedInput: Equatable {
        let inputType: Int
        let value: Float
    }

    let platform: Platform
    private(set) var recordedInputs: [RecordedInput] = []

    init(platform: Platform) {
        self.platform = platform
    }

    func initialize() -> Bool { true }
    func loadROM(romPath: String) -> Bool { true }
    func frame() -> Bool { true }

    func setInput(_ inputType: Int, value: Float) {
        recordedInputs.append(RecordedInput(inputType: inputType, value: value))
    }
}
