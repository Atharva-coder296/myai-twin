import streamlit as st
from openai import OpenAI

# Securely load API Key from secrets
client = OpenAI(api_key=st.secrets["OPENAI_API_KEY"])

st.set_page_config(page_title="MyAI Twin", layout="centered")
st.title("🧠 MyAI Twin")
st.write("Your AI-powered digital twin to talk, learn, and grow with you!")

user_input = st.text_input("Talk to your AI Twin 👇")

if user_input:
    with st.spinner("Thinking... 🤔"):
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful and intelligent AI Twin of the user."},
                {"role": "user", "content": user_input}
            ]
        )
        st.success(response.choices[0].message.content)
