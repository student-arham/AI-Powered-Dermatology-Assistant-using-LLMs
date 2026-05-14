import re
import streamlit as st
import os
import cv2
import numpy as np
from groq import Groq
from dotenv import load_dotenv
from PIL import Image
import pandas as pd
from reportlab.platypus import SimpleDocTemplate, Paragraph
from reportlab.lib.styles import getSampleStyleSheet
import speech_recognition as sr
import pyttsx3


def clean_text_for_pdf(text):
    text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
    text = re.sub(r"<.*?>", "", text)
    text = text.replace("|", " ")
    text = text.replace("\n", "<br/>")
    return text


def create_pdf(text, detected, confidence):
    file_path = "report.pdf"
    doc = SimpleDocTemplate(file_path)
    styles = getSampleStyleSheet()
    content = []

    cleaned_text = clean_text_for_pdf(text)

    content.append(Paragraph("AI Medical Report", styles["Title"]))
    content.append(Paragraph(f"Condition: {detected}", styles["Normal"]))
    content.append(Paragraph(f"Confidence: {confidence:.2f}%", styles["Normal"]))
    content.append(Paragraph(cleaned_text, styles["Normal"]))

    doc.build(content)
    return file_path


def get_voice_input():
    recognizer = sr.Recognizer()
    with sr.Microphone() as source:
        st.info("🎤 Listening... Speak now")
        audio = recognizer.listen(source)

    try:
        text = recognizer.recognize_google(audio)
        st.success(f"🗣️ You said: {text}")
        return text
    except:
        st.error("❌ Could not understand audio")
        return ""


def speak_text(text):
    engine = pyttsx3.init()
    engine.setProperty('rate', 150)
    engine.say(text)
    engine.runAndWait()


load_dotenv()
api_key = os.getenv("GROQ_API_KEY")
client = Groq(api_key=api_key)



if "history" not in st.session_state:
    st.session_state.history = []



st.set_page_config(page_title="AI Doctor", layout="centered")

st.markdown("""
    <h1 style='text-align: center; color: #4CAF50;'>🧠 AI Medical Assistant</h1>
    <p style='text-align: center;'>Upload a skin image for diagnosis</p>
""", unsafe_allow_html=True)



uploaded_file = st.file_uploader("📤 Upload Skin Image", type=["jpg", "png", "jpeg"])

if uploaded_file:
    image = Image.open(uploaded_file)

    st.markdown("### 🖼️ Uploaded Image")
    st.image(image, width="stretch")

 
    st.markdown("### 🎤 Doctor Voice Input")
    voice_query = ""

    if st.button("🎙️ Speak Your Query"):
        voice_query = get_voice_input()

   
    img = np.array(image)
    img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

    progress = st.progress(0)

    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]

    redness = np.mean(red - green)
    progress.progress(40)

    if redness > 20:
        detected = "Acne / Inflammation"
    else:
        detected = "Normal / Mild"

    confidence = min(100, abs(redness))
    progress.progress(70)

  
    st.markdown("###  Detection Result")
    col1, col2 = st.columns(2)

    col1.metric("Condition", detected)
    col2.metric("Confidence", f"{confidence:.2f}%")

    st.markdown("### 📊 Confidence Graph")
    chart_data = pd.DataFrame({"Confidence": [confidence]})
    st.bar_chart(chart_data)

   
    if st.button("🧠 Get Diagnosis"):
        with st.spinner("Analyzing...."):

            query = f"""
            Detected condition: {detected}
            Confidence: {confidence}

            Doctor query: {voice_query}

            Provide a realistic and practical medical response in plain text.

            Include:
            1. Simple explanation of condition
            2. Common symptoms
            3. Possible causes
            4. Practical treatment (home remedies + medical treatment)
            5. When to consult a doctor
            6. Prevention tips

            Avoid complex language. No symbols, no markdown.
            """

            response = client.chat.completions.create(
                model="openai/gpt-oss-20b",
                messages=[{"role": "user", "content": query}]
            )

            result = response.choices[0].message.content

        st.markdown("### AI Doctor Report")
        st.success(result)

       
        if st.button("🔊 Listen to Report"):
            speak_text(result)

        st.session_state.history.append({
            "Condition": detected,
            "Confidence": confidence
        })

      
        pdf_file = create_pdf(result, detected, confidence)

        with open(pdf_file, "rb") as f:
            st.download_button(
                "📄 Download Report",
                f,
                file_name="AI_Medical_Report.pdf"
            )

    progress.progress(100)



st.markdown("### 📁 Patient History")

if st.session_state.history:
    history_df = pd.DataFrame(st.session_state.history)
    st.dataframe(history_df)
    st.line_chart(history_df["Confidence"])
else:
    st.info("No history yet.")