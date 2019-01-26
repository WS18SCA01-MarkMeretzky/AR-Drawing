import UIKit

extension UIViewController {
    
    func transition(to child: UIViewController, completion: ((Bool) -> Void)? = nil) {
        let duration: TimeInterval = 0.3;
        
        let current: UIViewController? = children.last;
        addChild(child);
        
        let newView: UIView = child.view!;
        newView.translatesAutoresizingMaskIntoConstraints = true;
        newView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
        newView.frame = view.bounds;
        
        if let existing: UIViewController = current {
            existing.willMove(toParent: nil);
            
            transition(from: existing, to: child, duration: duration, options: [.transitionCrossDissolve], animations: { }, completion: { done in
                existing.removeFromParent();
                child.didMove(toParent: self);
                completion?(done);
            })
            
        } else {
            view.addSubview(newView);
            
            UIView.animate(withDuration: duration, delay: 0, options: [.transitionCrossDissolve], animations: { }, completion: { done in
                child.didMove(toParent: self);
                completion?(done);
            });
        }
    }
    
}
