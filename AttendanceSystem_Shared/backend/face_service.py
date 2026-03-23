"""
Face Recognition Service
Handles face detection, encoding, comparison, and image management
"""
import os
import json
import uuid
from typing import List, Optional, Tuple
from datetime import datetime

import numpy as np

# Create face images directory
FACE_IMAGES_DIR = os.path.join(os.path.dirname(__file__), "face_images")
os.makedirs(FACE_IMAGES_DIR, exist_ok=True)


class FaceRecognitionService:
    """Service class for face recognition operations"""
    
    def __init__(self, tolerance: float = 0.6):
        """
        Initialize face recognition service
        
        Args:
            tolerance: Distance threshold for face matching (lower = stricter)
        """
        self.tolerance = tolerance
        self._face_recognition = None
        self._cv2 = None
        self._initialized = False
    
    def initialize(self) -> bool:
        """Proactively initialize face recognition libraries"""
        return self._lazy_init()
    
    def _lazy_init(self) -> bool:
        """Lazy initialization of face recognition libraries"""
        if self._initialized:
            return True
            
        try:
            print("Loading Face Recognition models into memory... This may take a few seconds.")
            import face_recognition
            import cv2
            self._face_recognition = face_recognition
            self._cv2 = cv2
            self._initialized = True
            print("Face Recognition models loaded successfully.")
            return True
        except ImportError:
            print("Warning: Face recognition libraries (dlib/face-recognition/opencv) not found.")
            print("   Backend will continue to run without facial recognition features.")
            return False

    def _decode_rgb_image(self, image_bytes: bytes) -> Optional[np.ndarray]:
        """Decode image bytes into an RGB numpy image, downscaling large images for speed."""
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = self._cv2.imdecode(nparr, self._cv2.IMREAD_COLOR)
        if img is None:
            return None
        # Downscale large images to speed up face_recognition (CPU is slow on HD+)
        max_width = 600
        h, w = img.shape[:2]
        if w > max_width:
            scale = max_width / w
            img = self._cv2.resize(img, (max_width, int(h * scale)), interpolation=self._cv2.INTER_AREA)
        return self._cv2.cvtColor(img, self._cv2.COLOR_BGR2RGB)

    def _rotated_rgb(self, rgb_img: np.ndarray, quarter_turns: int) -> np.ndarray:
        """Return image rotated by 90-degree steps."""
        if quarter_turns % 4 == 0:
            return rgb_img
        return np.rot90(rgb_img, quarter_turns)
    
    def detect_face(self, image_bytes: bytes) -> Tuple[bool, Optional[np.ndarray], str]:
        """
        Detect a single face in an image
        """
        if not self._lazy_init():
            return False, None, "Face recognition libraries not available on this system."

        rgb_img = self._decode_rgb_image(image_bytes)
        if rgb_img is None:
            return False, None, "Could not decode image"

        # Try original orientation first, then common desktop/webcam fallbacks.
        search_order = [0, 2, 1, 3]
        saw_multiple_faces = False

        for turns in search_order:
            candidate = self._rotated_rgb(rgb_img, turns)
            face_locations = self._face_recognition.face_locations(candidate)

            if len(face_locations) == 1:
                return True, candidate, "Face detected successfully"

            if len(face_locations) > 1:
                saw_multiple_faces = True

        if saw_multiple_faces:
            return False, None, "Multiple faces detected. Please use an image with only one face."

        return False, None, "No face detected in the image"

    def detect_all_faces(self, image_bytes: bytes) -> Tuple[bool, Optional[np.ndarray], List[Tuple], str]:
        """
        Detect all faces in an image for room scanning
        """
        if not self._lazy_init():
            return False, None, [], "Face recognition libraries not available."

        rgb_img = self._decode_rgb_image(image_bytes)
        if rgb_img is None:
            return False, None, [], "Could not decode image"

        face_locations = self._face_recognition.face_locations(rgb_img)

        if face_locations:
            return True, rgb_img, face_locations, f"Detected {len(face_locations)} faces"

        # Retry with rotated frames for upside-down / sideways webcam captures.
        for turns in [2, 1, 3]:
            candidate = self._rotated_rgb(rgb_img, turns)
            candidate_locations = self._face_recognition.face_locations(candidate)
            if candidate_locations:
                return True, candidate, candidate_locations, f"Detected {len(candidate_locations)} faces"

        return True, rgb_img, face_locations, f"Detected {len(face_locations)} faces"
    
    def encode_face(self, rgb_image: np.ndarray) -> Optional[List[float]]:
        """
        Generate face encoding from RGB image
        """
        if not self._lazy_init():
            return None
        
        face_locations = self._face_recognition.face_locations(rgb_image)
        if not face_locations:
            return None
        
        encodings = self._face_recognition.face_encodings(rgb_image, face_locations)
        if not encodings:
            return None
        
        return encodings[0].tolist()
    
    def encode_multiple_faces(self, image_bytes_list: List[bytes]) -> Tuple[bool, Optional[List[float]], str]:
        """
        Process multiple face images and generate averaged encoding
        
        Args:
            image_bytes_list: List of image bytes
            
        Returns:
            Tuple of (success, averaged_encoding, message)
        """
        encodings = []
        
        for i, image_bytes in enumerate(image_bytes_list):
            success, rgb_img, message = self.detect_face(image_bytes)
            if not success:
                return False, None, f"Image {i+1}: {message}"
            
            encoding = self.encode_face(rgb_img)
            if encoding is None:
                return False, None, f"Image {i+1}: Could not encode face"
            
            encodings.append(encoding)
        
        # Average all encodings for more robust recognition
        if encodings:
            averaged = np.mean(encodings, axis=0).tolist()
            return True, averaged, f"Successfully processed {len(encodings)} images"
        
        return False, None, "No valid face encodings generated"
    
    def compare_faces(
        self,
        known_encoding: List[float],
        unknown_encoding: List[float]
    ) -> Tuple[bool, float]:
        """
        Compare two face encodings
        """
        if not self._lazy_init():
            return False, 0.0
        
        known = np.array(known_encoding)
        unknown = np.array(unknown_encoding)
        
        # Calculate face distance
        distance = self._face_recognition.face_distance([known], unknown)[0]
        
        # Convert distance to confidence (1 - distance)
        confidence = 1 - distance
        
        # Check if match
        is_match = distance <= self.tolerance
        
        return is_match, float(confidence)
    
    def find_best_match(
        self,
        known_encodings: List[Tuple[int, str, List[float]]],
        unknown_encoding: List[float]
    ) -> Tuple[Optional[int], Optional[str], float]:
        """
        Find the best matching face from a list of known encodings
        """
        if not known_encodings:
            return None, None, 0.0
        
        best_match_id = None
        best_match_name = None
        best_confidence = 0.0
        
        for user_id, user_name, encoding in known_encodings:
            is_match, confidence = self.compare_faces(encoding, unknown_encoding)
            if is_match and confidence > best_confidence:
                best_confidence = confidence
                best_match_id = user_id
                best_match_name = user_name
        
        return best_match_id, best_match_name, best_confidence

    def find_all_matches(
        self,
        known_encodings: List[Tuple[int, str, List[float]]],
        unknown_encodings: List[List[float]]
    ) -> List[Tuple[int, str, float]]:
        """
        Find matches for all faces detected in a room scan
        """
        matches = []
        identified_user_ids = set()
        
        for face_enc in unknown_encodings:
            user_id, name, confidence = self.find_best_match(known_encodings, face_enc)
            if user_id and user_id not in identified_user_ids and confidence >= self.tolerance:
                matches.append((user_id, name, confidence))
                identified_user_ids.add(user_id)
                
        return matches
    
    def save_face_image(self, image_bytes: bytes, user_id: int) -> str:
        """
        Save face image to disk
        
        Args:
            image_bytes: Image bytes
            user_id: User ID for organizing images
            
        Returns:
            Path to saved image
        """
        # Create user directory
        user_dir = os.path.join(FACE_IMAGES_DIR, str(user_id))
        os.makedirs(user_dir, exist_ok=True)
        
        # Generate unique filename
        filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}.jpg"
        filepath = os.path.join(user_dir, filename)
        
        # Save image
        with open(filepath, "wb") as f:
            f.write(image_bytes)
        
        return filepath
    
    def delete_face_images(self, user_id: int) -> bool:
        """
        Delete all face images for a user
        
        Args:
            user_id: User ID
            
        Returns:
            Success status
        """
        import shutil
        
        user_dir = os.path.join(FACE_IMAGES_DIR, str(user_id))
        if os.path.exists(user_dir):
            shutil.rmtree(user_dir)
            return True
        return False


class ExamProctorService:
    """
    Service class for exam proctoring/cheating detection
    Uses YOLOv8 for object detection and face_recognition for identity verification
    """
    
    # Objects that indicate potential cheating
    SUSPICIOUS_OBJECTS = {
        'cell phone': {'label': 'Phone', 'color': 'red', 'score': 40},
        'book': {'label': 'Book', 'color': 'orange', 'score': 25},
        'laptop': {'label': 'Laptop', 'color': 'orange', 'score': 20},
        'remote': {'label': 'Remote/Device', 'color': 'orange', 'score': 15},
        'mouse': {'label': 'Mouse', 'color': 'yellow', 'score': 5},
        'keyboard': {'label': 'Keyboard', 'color': 'yellow', 'score': 5},
        'tv': {'label': 'Monitor/TV', 'color': 'orange', 'score': 15},
        'bottle': {'label': 'Bottle', 'color': 'green', 'score': 0},
        'cup': {'label': 'Cup', 'color': 'green', 'score': 0},
        'person': {'label': 'Person', 'color': 'blue', 'score': 0},  # Handled separately
    }
    
    def __init__(self):
        self._yolo_model = None
        self._initialized = False
        self._yolo_available = False
        self._face_service = None
        self._cv2 = None
    
    def _lazy_init(self) -> bool:
        """Lazy initialization of exam proctoring dependencies"""
        if self._initialized:
            return True
        
        try:
            self._face_service = face_service  # Use the global face service
            if not self._face_service._lazy_init():
                print("Warning: Face recognition libraries not available for exam proctoring.")
                return False

            self._cv2 = self._face_service._cv2

            try:
                from ultralytics import YOLO
                # Load YOLOv8 nano model (smallest, fastest)
                self._yolo_model = YOLO('yolov8n.pt')
                self._yolo_available = True
                print("ExamProctorService initialized with YOLOv8")
            except Exception as yolo_error:
                self._yolo_model = None
                self._yolo_available = False
                print(f"Warning: YOLO unavailable, running face-only proctor mode: {yolo_error}")
            self._initialized = True
            return True
        except Exception as e:
            print(f"Warning: Could not initialize exam proctoring: {e}")
            return False
    
    def detect_objects(self, image_bytes: bytes) -> Tuple[List[dict], np.ndarray]:
        """
        Detect all objects in an image using YOLOv8
        
        Returns:
            Tuple of (list of detected objects, image as numpy array)
        """
        if not self._lazy_init():
            return [], None
        
        # Convert bytes to numpy array
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = self._cv2.imdecode(nparr, self._cv2.IMREAD_COLOR)
        
        if img is None:
            return [], None
        
        if not self._yolo_available or self._yolo_model is None:
            return [], img

        # Get image dimensions for normalization
        height, width = img.shape[:2]
        
        # Run YOLO inference
        results = self._yolo_model(img, verbose=False)
        
        detected_objects = []
        
        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue
                
            for box in boxes:
                # Get class name
                cls_id = int(box.cls[0])
                class_name = self._yolo_model.names[cls_id].lower()
                confidence = float(box.conf[0])
                
                # Get bounding box (normalized coordinates 0-1)
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                bbox = [x1/width, y1/height, x2/width, y2/height]
                
                # Check if this is a suspicious object
                if class_name in self.SUSPICIOUS_OBJECTS:
                    obj_info = self.SUSPICIOUS_OBJECTS[class_name]
                    detected_objects.append({
                        'type': class_name.replace(' ', '_'),
                        'label': obj_info['label'],
                        'confidence': confidence,
                        'bbox': bbox,
                        'color': obj_info['color'],
                        'suspicion_score': obj_info['score']
                    })
        
        return detected_objects, img
    
    def analyze_exam_frame(
        self,
        image_bytes: bytes,
        known_encodings: List[Tuple[int, str, List[float]]],
        expected_student_id: Optional[int] = None
    ) -> dict:
        """
        Analyze a single frame for exam proctoring
        
        Args:
            image_bytes: Image data
            known_encodings: List of (user_id, name, encoding) for verification
            expected_student_id: Optional ID of the student who should be taking the exam
            
        Returns:
            Analysis result dictionary
        """
        from datetime import datetime
        
        if not self._lazy_init():
            return {
                'student_verified': False,
                'student_id': None,
                'student_name': None,
                'face_count': 0,
                'gaze_direction': 'unknown',
                'detected_objects': [],
                'suspicion_score': 0,
                'violations': ['Face recognition service not available'],
                'is_cheating': False,
                'timestamp': datetime.now(),
                'message': 'Exam proctoring service not initialized'
            }
        
        # Detect objects using YOLO
        detected_objects, img = self.detect_objects(image_bytes)
        
        # Detect faces using face_recognition
        success, rgb_img, face_locations, face_msg = self._face_service.detect_all_faces(image_bytes)
        
        face_count = len(face_locations) if success else 0
        violations = []
        suspicion_score = 0.0
        student_verified = False
        student_id = None
        student_name = None
        gaze_direction = 'center'
        
        # Process detected objects
        for obj in detected_objects:
            if obj['type'] != 'person':  # Person is handled via face detection
                suspicion_score += obj['suspicion_score'] * obj['confidence']
                if obj['suspicion_score'] > 0:
                    violations.append(f"{obj['label']} detected ({obj['confidence']*100:.0f}%)")
        
        # Add face objects to detected list
        if success and face_locations:
            for i, (top, right, bottom, left) in enumerate(face_locations):
                # Normalize face bounding box
                height, width = rgb_img.shape[:2]
                bbox = [left/width, top/height, right/width, bottom/height]
                
                detected_objects.append({
                    'type': 'face',
                    'label': f'Face {i+1}',
                    'confidence': 1.0,
                    'bbox': bbox,
                    'color': 'green',  # Will be updated after verification
                    'suspicion_score': 0
                })
        
        # Verify student identity
        if success and face_locations and known_encodings:
            try:
                import face_recognition

                # Get all face encodings from the image
                face_encodings = face_recognition.face_encodings(rgb_img, face_locations)

                for enc in face_encodings:
                    match_id, match_name, confidence = self._face_service.find_best_match(
                        known_encodings, enc.tolist()
                    )
                    if match_id:
                        # Found a match
                        if expected_student_id is None or match_id == expected_student_id:
                            student_verified = True
                            student_id = match_id
                            student_name = match_name
                            # Update face color to green for verified
                            for obj in detected_objects:
                                if obj['type'] == 'face' and obj['label'] == 'Face 1':
                                    obj['color'] = 'green'
                                    obj['label'] = f'OK {match_name}'
                            break
            except ImportError:
                pass
        
        # Check for multiple faces (potential helper)
        if face_count > 1:
            extra_faces = face_count - 1
            suspicion_score += extra_faces * 30  # 30 points per extra face
            violations.append(f"{extra_faces} extra person(s) detected")
            # Mark additional faces as suspicious
            for i, obj in enumerate(detected_objects):
                if obj['type'] == 'face' and i > 0:
                    obj['color'] = 'blue'
                    obj['label'] = f'Extra Person {i}'
        
        # Check if no face detected
        if face_count == 0:
            suspicion_score += 20
            violations.append("No student face detected")
        
        # Check if wrong student
        if expected_student_id and student_id and student_id != expected_student_id:
            suspicion_score += 50
            violations.append("Wrong student detected")
        
        # Cap suspicion score at 100
        suspicion_score = min(100.0, suspicion_score)
        
        # Determine if cheating
        is_cheating = suspicion_score >= 50
        
        # Generate message
        if is_cheating:
            message = f"CHEATING SUSPECTED - Score: {suspicion_score:.0f}%"
        elif suspicion_score > 0:
            message = f"Suspicious activity - Score: {suspicion_score:.0f}%"
        else:
            message = "No issues detected"

        if not self._yolo_available and message == "No issues detected":
            message = "No issues detected (face-only mode)"
        
        return {
            'student_verified': student_verified,
            'student_id': student_id,
            'student_name': student_name,
            'face_count': face_count,
            'gaze_direction': gaze_direction,
            'detected_objects': detected_objects,
            'suspicion_score': suspicion_score,
            'violations': violations,
            'is_cheating': is_cheating,
            'timestamp': datetime.now(),
            'message': message
        }


# Global instances
face_service = FaceRecognitionService()
exam_proctor_service = ExamProctorService()



