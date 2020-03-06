import Foundation

class KeyManagement {
	private static var secret:[UInt8] = []
	//TODO : maybe KayChain is better place to store the secret
	static public var key:[UInt8] { get { return KeyManagement.secret } set(newKey) { KeyManagement.secret = newKey } }
	
	static public func importKeyBundle(keyBundle:String, password:String) -> Bool {
		guard let keyBundleBytes = SPApplication.crypto.base64ToByte(data: keyBundle) else {
			return false
		}
		do {
			try SPApplication.crypto.importKeyBundle(keys: keyBundleBytes, password: password)
		} catch {
			print(error)
			return false
		}
		
		return true
	}
}