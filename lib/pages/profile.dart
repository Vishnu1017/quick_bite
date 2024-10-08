import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_bite/pages/onboard.dart';
import 'package:quick_bite/service/auth.dart';
import 'package:quick_bite/service/shared_pref.dart';
import 'package:random_string/random_string.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? name, email, phoneNumber, profileImageUrl, address;
  final ImagePicker _picker = ImagePicker();
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    checkUserAuthentication();
  }

  Future<void> checkUserAuthentication() async {
    User? user = await AuthMethods().getCurrentUser();
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Onboard()),
      );
    }
  }

  Future<void> getImage() async {
    var image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImage = File(image.path);
      setState(() {
        uploadItem();
      });
    }
  }

  Future<void> uploadItem() async {
    if (selectedImage != null) {
      String addId = randomAlphaNumeric(10);
      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child("profileImages").child(addId);
      final UploadTask task = firebaseStorageRef.putFile(selectedImage!);
      var downloadUrl = await (await task).ref.getDownloadURL();
      String userId = AuthMethods().getCurrentUserId();
      if (userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection("users").doc(userId).set(
          {
            'profileImage': downloadUrl,
          },
          SetOptions(merge: true),
        );
        await SharedPreferenceHelper().saveUserProfile(downloadUrl);
        profileImageUrl = downloadUrl;
        setState(() {});
      } else {
        print("User ID is empty.");
      }
    }
  }

  Future<void> updateUserFields(String newName, String newEmail,
      String newPhone, String newAddress) async {
    String userId = AuthMethods().getCurrentUserId();
    if (userId.isNotEmpty) {
      await FirebaseFirestore.instance.collection("users").doc(userId).set(
        {
          'Name': newName,
          'Email': newEmail,
          'PhoneNumber': newPhone,
          'Address': newAddress,
        },
        SetOptions(merge: true),
      );
      setState(() {
        name = newName;
        email = newEmail;
        phoneNumber = newPhone;
        address = newAddress; // Add this line to update local address state
      });
    }
  }

  Future<void> showEditDialog() async {
    TextEditingController nameController = TextEditingController(text: name);
    TextEditingController emailController = TextEditingController(text: email);
    TextEditingController phoneController =
        TextEditingController(text: phoneNumber);
    TextEditingController addressController =
        TextEditingController(text: address);

    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: nameController,
                      label: 'Name',
                      hint: 'Enter your name',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your phone number',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        } else if (!RegExp(r'^\+?[0-9]{10,15}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: addressController,
                      label: 'Address',
                      hint: 'Enter your address',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            _buildDialogButton(
              text: 'Cancel',
              color: Colors.red.shade400,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            _buildDialogButton(
              text: 'Save',
              color: Colors.green.shade400,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  updateUserFields(
                    nameController.text,
                    emailController.text,
                    phoneController.text,
                    addressController.text,
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDialogButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height / 4,
        flexibleSpace: Container(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    height: MediaQuery.of(context).size.height / 4.3,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.elliptical(
                          MediaQuery.of(context).size.width,
                          105,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: getImage,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height / 6.5,
                        ),
                        child: Material(
                          elevation: 10,
                          borderRadius: BorderRadius.circular(60),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: profileImageUrl != null
                                ? Image.network(
                                    profileImageUrl!,
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 120,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(60),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 70),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name ?? "Loading...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(AuthMethods().getCurrentUserId())
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('User does not exist'));
            }

            var userData = snapshot.data!;
            var userMap = userData.data() as Map<String, dynamic>; // Cast here

            // Now check for keys safely
            name = userMap['Name'];
            email = userMap['Email'];
            phoneNumber = userMap.containsKey('PhoneNumber')
                ? userMap['PhoneNumber']
                : null;
            profileImageUrl = userMap.containsKey('profileImage')
                ? userMap['profileImage']
                : null;
            address =
                userMap.containsKey('Address') ? userMap['Address'] : null;

            return SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: showEditDialog,
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text(
                              'Edit Profile',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildUserInfoCard(Icons.person, "Name", name ?? "Not set"),
                    const SizedBox(height: 30),
                    buildUserInfoCard(Icons.mail, "Email", email ?? "Not set"),
                    const SizedBox(height: 30),
                    buildUserInfoCard(
                        Icons.phone, "Phone", phoneNumber ?? "Not set"),
                    const SizedBox(height: 30),
                    buildUserInfoCard(
                        Icons.home, "Address", address ?? "Not set"),
                    const SizedBox(height: 30),
                    buildUserInfoCard(Icons.description, "Terms and Condition",
                        "Read more..."),
                    const SizedBox(height: 30),
                    buildDeleteAccountButton(),
                    const SizedBox(height: 30),
                    buildLogoutButton(),
                  ],
                ),
              ),
            );
          }),
    );
  }

  Widget buildUserInfoCard(IconData icon, String title, String content) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.black),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      content,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDeleteAccountButton() {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () async {
          await AuthMethods().SignOut();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Onboard()),
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          backgroundColor: Colors.red,
        ),
        child: Row(
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                "Delete Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLogoutButton() {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () async {
          await AuthMethods().SignOut();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Onboard()),
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          backgroundColor: Colors.red,
        ),
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
