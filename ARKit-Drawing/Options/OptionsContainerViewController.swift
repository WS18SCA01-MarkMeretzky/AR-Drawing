import UIKit;
import SceneKit;

protocol OptionsViewControllerDelegate: class {
    func objectSelected(node: SCNNode);
    func undoLastObject();
    func togglePlaneVisualization();
    func resetScene();
}

class OptionsContainerViewController: UIViewController, UINavigationControllerDelegate {
    
    private var shape: Shape!;
    private var color: UIColor!;
    
    private var nav: UINavigationController?;
    
    weak var delegate: OptionsViewControllerDelegate?;
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        let navigationController: UINavigationController = UINavigationController(rootViewController: rootOptionPicker());
        nav = navigationController;
        
        transition(to: navigationController);
    }
    
    override func viewWillLayoutSubviews() {
        preferredContentSize = CGSize(width: 320, height: 600);
    }
    
    private func rootOptionPicker() -> UIViewController {
        let options: [Option<ShapeOption>] = [
            Option(option: ShapeOption.addShape),
            Option(option: ShapeOption.addScene),
            Option(option: ShapeOption.togglePlane, showsDisclosureIndicator: false),
            Option(option: ShapeOption.undoLastShape, showsDisclosureIndicator: false),
            Option(option: ShapeOption.resetScene, showsDisclosureIndicator: false)
        ];
        
        let selector: OptionSelectorViewController = OptionSelectorViewController(options: options);
        selector.optionSelectionCallback = { [unowned self] option in
            switch option {
            case .addShape:
                self.nav?.pushViewController(self.shapePicker(), animated: true);
            case .addScene:
                self.nav?.pushViewController(self.scenePicker(), animated: true);
            case .togglePlane:
                self.delegate?.togglePlaneVisualization();
            case .undoLastShape:
                self.delegate?.undoLastObject();
            case .resetScene:
                self.delegate?.resetScene();
            }
        }
        return selector;
    }
    
    private func scenePicker() -> UIViewController {
        let resourceFolder: String = "models.scnassets"
        let availableScenes: [String] = {
            let modelsURL: URL = Bundle.main.url(forResource: resourceFolder, withExtension: nil)!
            
            let fileEnumerator: FileManager.DirectoryEnumerator = FileManager().enumerator(at: modelsURL, includingPropertiesForKeys: [])!
            
            return fileEnumerator.compactMap { element in
                let url: URL = element as! URL;
                
                guard url.pathExtension == "scn" else { return nil; }
                
                return url.lastPathComponent;
            }
        }();
        
        let options: [Option<String>] = availableScenes.map { Option(name: $0, option: $0, showsDisclosureIndicator: false) }
        let selector: OptionSelectorViewController = OptionSelectorViewController(options: options);
        selector.optionSelectionCallback = { [unowned self] name in
            let nameWithoutExtension: String = name.replacingOccurrences(of: ".scn", with: "");
            let scene: SCNScene = SCNScene(named: "\(resourceFolder)/\(nameWithoutExtension)/\(name)")!
            self.delegate?.objectSelected(node: scene.rootNode);
        }
        return selector;
    }
    
    private func shapePicker() -> UIViewController {
        let shapes: [Shape] = [.box, .sphere, .cylinder, .cone, .pyramid /*.torus*/];
        let options: [Option<Shape>] = shapes.map { Option(option: $0) }
        
        let selector: OptionSelectorViewController = OptionSelectorViewController(options: options);
        selector.optionSelectionCallback = { [unowned self] option in
            self.shape = option;
            self.nav?.pushViewController(self.colorPicker(), animated: true);
        }
        return selector;
    }
    
    private func colorPicker() -> UIViewController {
        let colors: [(String, UIColor)] = [
            ("Red",    .red),
            ("Orange", .orange),
            ("Yellow", .yellow),
            ("Green",  .green),
            ("Blue",   .blue),
            ("Brown",  .brown),
            ("White",  .white),
            ("Black",  .black)
        ];
        let options: [Option] = colors.map {Option(name: $0.0, option: $0.1, showsDisclosureIndicator: true);}
        
        let selector: OptionSelectorViewController = OptionSelectorViewController(options: options);
        selector.optionSelectionCallback = { [unowned self] option in
            self.color = option;
            self.nav?.pushViewController(self.sizePicker(), animated: true);
        }
        return selector;
    }
    
    private func sizePicker() -> UIViewController {
        let sizes: [Size] = [.small, .medium, .large];
        let options = sizes.map { Option(option: $0, showsDisclosureIndicator: false) }
        
        let selector: OptionSelectorViewController = OptionSelectorViewController(options: options);
        selector.optionSelectionCallback = { [unowned self] option in
            let node: SCNNode = self.createNode(shape: self.shape, color: self.color, size: option);
            self.delegate?.objectSelected(node: node);
        }
        return selector;
    }
    
    private func createNode(shape: Shape, color: UIColor, size: Size) -> SCNNode {
        let geometry: SCNGeometry;
        let meters: CGFloat;
        
        switch size {
        case .small:
            meters = 0.033;
        case .medium:
            meters = 0.1;
        case .large:
            meters = 0.3;
        case .extraLarge:
            meters = 0.6;   //p. 510
        }
        
        switch shape {
        case .box:
            geometry = SCNBox(width: meters, height: meters, length: meters, chamferRadius: 0.0);
        case .cone:
            geometry = SCNCone(topRadius: 0.0, bottomRadius: meters, height: meters);
        case .cylinder:
            geometry = SCNCylinder(radius: meters / 2, height: meters)
        case .sphere:
            geometry = SCNSphere(radius: meters);
        /*
        case .torus:
            geometry = SCNTorus(ringRadius: meters*1.5, pipeRadius: meters * 0.2);
        */
        case .pyramid:
            geometry = SCNPyramid(width: meters, height: meters * 1.5, length: meters); //p. 509
        }
        
        geometry.firstMaterial?.diffuse.contents = color;
        
        return SCNNode(geometry: geometry);
    }
}
