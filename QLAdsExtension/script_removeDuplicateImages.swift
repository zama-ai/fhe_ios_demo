import Foundation
import CryptoKit
import CoreImage

/*
 This script:
 ✅ Detects duplicate images via their SHA1.
 ✅ Renames the first image in the group with its hash.
 ✅ Deletes all other copies.
 ✅ Updates JSON with new image names (hash).
 ✅ Removes metadata from all JPEG images to reduce file size.
 */

let folderPath = "/Users/dim/Developer/Zama/deai-dot-products/TestConcretMLX/images"
let textFilePath = "/Users/dim/Developer/Zama/deai-dot-products/TestConcretMLX/ads.json"

/// Calcule le hash SHA1 d'un fichier
func sha1Hash(of fileURL: URL) -> String? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    let hash = Insecure.SHA1.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}

/// Remove metadata from a JPEG image and overwrite the file
func removeMetadata(from imageURL: URL) {
    guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let imageType = CGImageSourceGetType(imageSource),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        print("❌ Failed to process image: \(imageURL.lastPathComponent)")
        return
    }
    
    let outputURL = imageURL
    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, imageType, 1, nil) else {
        print("❌ Failed to create image destination for \(imageURL.lastPathComponent)")
        return
    }
    
    // Save the image without metadata
    CGImageDestinationAddImage(destination, image, nil)
    if CGImageDestinationFinalize(destination) {
        print("📷 Metadata removed from: \(imageURL.lastPathComponent)")
    } else {
        print("❌ Failed to remove metadata from \(imageURL.lastPathComponent)")
    }
}

let fileManager = FileManager.default
let folderURL = URL(fileURLWithPath: folderPath)

var hashDictionary = [String: [URL]]()
var renameMap = [String: String]() // Stocke les anciens noms et leurs nouveaux noms

do {
    let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
    
    for file in files where file.isFileURL {
        if let hash = sha1Hash(of: file) {
            hashDictionary[hash, default: []].append(file)
        }
    }
    
    for (hash, fileList) in hashDictionary {
        guard fileList.count > 1 else { continue } // Ignorer les fichiers uniques
        
        let firstFile = fileList[0]
        let newFileName = "\(hash)\(firstFile.pathExtension.isEmpty ? "" : ".\(firstFile.pathExtension)")"
        let newFilePath = folderURL.appendingPathComponent(newFileName)
        
        // Vérifier si le fichier renommé existe déjà
        if !fileManager.fileExists(atPath: newFilePath.path) {
            do {
                try fileManager.moveItem(at: firstFile, to: newFilePath)
                print("✅ Renommé: \(firstFile.lastPathComponent) → \(newFileName)")
                renameMap[firstFile.lastPathComponent] = newFileName
            } catch {
                print("❌ Erreur lors du renommage de \(firstFile.lastPathComponent): \(error)")
            }
        } else {
            print("⚠️ Le fichier \(newFileName) existe déjà, pas de renommage.")
        }
        
        // Supprimer les autres copies
        for duplicateFile in fileList.dropFirst() {
            do {
                renameMap[duplicateFile.lastPathComponent] = newFileName // Associe le fichier supprimé au nom du hash
                try fileManager.removeItem(at: duplicateFile)
                print("🗑 Supprimé: \(duplicateFile.lastPathComponent)")
            } catch {
                print("❌ Erreur lors de la suppression de \(duplicateFile.lastPathComponent): \(error)")
            }
        }
    }
    
    // Modifier le fichier texte en remplaçant les anciens noms par les nouveaux
    var textContent = try String(contentsOfFile: textFilePath, encoding: .utf8)
    
    for (oldName, newName) in renameMap {
        textContent = textContent.replacingOccurrences(of: oldName, with: newName)
    }
    
    try textContent.write(toFile: textFilePath, atomically: true, encoding: .utf8)
    print("📝 Fichier texte mis à jour avec les nouveaux noms d'images.")
    
    // Remove metadata from all JPEG files
    for file in files where file.pathExtension.lowercased() == "jpg" || file.pathExtension.lowercased() == "jpeg" {
        removeMetadata(from: file)
    }
    
} catch {
    print("❌ Erreur lors de l'exécution du script: \(error)")
}
