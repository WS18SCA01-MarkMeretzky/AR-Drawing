import UIKit;
import SceneKit;
import ARKit;

class ViewController: UIViewController, ARSCNViewDelegate {
    var selectedNode: SCNNode? = nil;          //p. 511
    var placedNodes: [SCNNode] = [SCNNode]();  //p. 515
    var planeNodes: [SCNNode] = [SCNNode]();   //p. 515

    @IBOutlet var sceneView: ARSCNView!;
    let configuration: ARWorldTrackingConfiguration = ARWorldTrackingConfiguration();
    
    enum ObjectPlacementMode {
        case freeform, plane, image;
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            reloadConfiguration(removeAnchors: false);   //pp. 517, 527
        }
    }
    
    var showPlaneOverlay: Bool = false { //p. 520
        didSet {
            for node in planeNodes {
                node.isHidden = !showPlaneOverlay;
            }
        }
    }
    
    var lastObjectPlacedPoint: CGPoint? = nil;  //p. 523
    let touchDistanceThreshold: CGFloat = 40.0; //p. 523
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        sceneView.delegate = self;
        sceneView.autoenablesDefaultLighting = true;
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        reloadConfiguration();                //p. 517
        sceneView.session.run(configuration); //p. 518
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
        sceneView.session.pause();
    }
    
    func reloadConfiguration(removeAnchors: Bool = true) {   //pp. 518, 526-527
        configuration.planeDetection = [.horizontal, .vertical];
        configuration.detectionImages = (objectMode == .image) ? ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) : nil;
        
        let options: ARSession.RunOptions;
        if removeAnchors {
            options = [.removeExistingAnchors];
            for node in planeNodes {
                node.removeFromParentNode();
            }
            planeNodes.removeAll();
            for node in placedNodes {
                node.removeFromParentNode();
            }
            placedNodes.removeAll()
        } else {
            options = [];
        }

        sceneView.session.run(configuration, options: options);
    }

    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform;
        case 1:
            objectMode = .plane;
        case 2:
            objectMode = .image;
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController: OptionsContainerViewController = segue.destination as! OptionsContainerViewController;
            optionsViewController.delegate = self;
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event);

        guard let node: SCNNode = selectedNode,
            let touch: UITouch = touches.first else {
            return;
        }

        switch objectMode {
        case .freeform:
            addNodeInFront(node);
        case .plane:
            let touchPoint: CGPoint = touch.location(in: sceneView); //p. 521
            addNode(node, toPlaneUsingPoint: touchPoint);
        case .image:
            break;
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { //p. 523
        super.touchesMoved(touches, with: event);

        guard objectMode == .plane,
            let node: SCNNode = selectedNode,
            let touch: UITouch = touches.first,
            let lastTouchPoint: CGPoint = lastObjectPlacedPoint //p. 524
            else { return; }

        let newTouchPoint: CGPoint = touch.location(in: sceneView);
        let distance: CGFloat = hypot(newTouchPoint.x - lastTouchPoint.x, newTouchPoint.y - lastTouchPoint.y);
        
        if distance > touchDistanceThreshold { //p. 524
            addNode(node, toPlaneUsingPoint: newTouchPoint);
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { //p. 525
        super.touchesEnded(touches, with: event);
        lastObjectPlacedPoint = nil;
    }
    
    //Called from touchesBegan(_:with:) and touchesMoved(_:with:).
    
    func addNode(_ node: SCNNode, toPlaneUsingPoint point: CGPoint) { //p. 522
        let results: [ARHitTestResult] = sceneView.hitTest(point, types: [.existingPlaneUsingExtent]);
        
        if let match: ARHitTestResult = results.first {

            // Give the node the correct orientation.
            guard let anchor: ARAnchor = match.anchor else {
                fatalError("ARHitTestResult had no anchor.");
            }
            node.transform = SCNMatrix4(anchor.transform);

            let position: simd_float4 = match.worldTransform.columns.3;
            node.position = SCNVector3(x: position.x, y: position.y, z: position.z);
            
            addNodeToSceneRoot(node);
            lastObjectPlacedPoint = point; //p. 524
        }
    }
    
    func addNodeInFront(_ node: SCNNode) {
        guard let currentFrame: ARFrame = sceneView.session.currentFrame else {
            return;
        }

        // Set transform of node to be 20cm in front of camera.
        var translation: simd_float4x4 = matrix_identity_float4x4;
        translation.columns.3.z = -0.2;
        node.simdTransform = matrix_multiply(currentFrame.camera.transform, translation);

        addNodeToSceneRoot(node);   //p. 514
    }
    
    //Place a node in front of the camera.
    
    func addNodeToSceneRoot(_ node: SCNNode) {   //p. 514
        let cloneNode: SCNNode = node.clone();
        sceneView.scene.rootNode.addChildNode(cloneNode);
        placedNodes.append(cloneNode);   //p. 515
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) { //p. 516
        if let imageAnchor: ARImageAnchor = anchor as? ARImageAnchor {
            nodeAdded(node, for: imageAnchor);
        } else if let planeAnchor: ARPlaneAnchor = anchor as? ARPlaneAnchor {
            nodeAdded(node, for: planeAnchor);
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) { //p. 519
        guard let planeAnchor: ARPlaneAnchor = anchor as? ARPlaneAnchor,
            let planeNode: SCNNode = node.childNodes.first,
            let plane: SCNPlane = planeNode.geometry as? SCNPlane
            else { return }
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z);
        plane.width = CGFloat(planeAnchor.extent.x);
        plane.height = CGFloat(planeAnchor.extent.z);
    }
    
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode { //pp. 519-520
        let node: SCNNode = SCNNode();
        node.geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z));
        node.eulerAngles.x = -.pi / 2;
        node.opacity = 0.25;
        return node;
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) { //p. 516, 517, 519
        let floor: SCNNode = createFloor(planeAnchor: anchor);
        floor.isHidden = !showPlaneOverlay; //p. 520
        node.addChildNode(floor);
        planeNodes.append(floor);
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) { //pp. 516, 517
        if let selectedNode: SCNNode = selectedNode {
            addNode(selectedNode, toImageUsingParentNode: node);
        }
    }
    
    //Attach a node to an image we recognized, p. 517.
    
    func addNode(_ node: SCNNode, toImageUsingParentNode parentNode: SCNNode) {
        let cloneNode: SCNNode = node.clone();
        parentNode.addChildNode(cloneNode);
        placedNodes.append(cloneNode);
    }
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil);
        selectedNode = node;   //p. 511
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil);
        showPlaneOverlay = !showPlaneOverlay;   //p. 521
    }
    
    func undoLastObject() {
        if let lastNode: SCNNode = placedNodes.last { //p. 526
            lastNode.removeFromParentNode();
            placedNodes.removeLast();
        }
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil);
        reloadConfiguration(); //p. 527
    }
}
