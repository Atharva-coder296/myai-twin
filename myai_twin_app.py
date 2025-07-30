import streamlit as st
from openai import OpenAI

# Securely load your OpenAI API key from Streamlit secrets
client = OpenAI(api_key=st.secrets["OPENAI_API_KEY"])

st.set_page_config(page_title="MyAI Twin", page_icon="🤖")
st.title("👤 MyAI Twin - Your Personal AI Clone")

st.markdown("Talk to your digital twin. Ask anything, anytime.")

user_input = st.text_input("You:", "")

if user_input:
    with st.spinner("Thinking like you..."):
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful and intelligent AI Twin of the user."},
                {"role": "user", "content": user_input}
            ]
        )
        reply = response.choices[0].message.content
        st.markdown(f"**MyAI Twin:** {reply}")

