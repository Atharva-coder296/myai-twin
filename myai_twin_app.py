import streamlit as st
import openai

st.set_page_config(page_title="MyAI Twin", layout="centered")

st.title("🧠 MyAI Twin")
st.caption("Your Personal AI Assistant & Digital Twin")

openai.api_key = st.text_input("🔐 Enter your OpenAI API Key", type="password")

user_input = st.text_area("🗣️ What do you want to talk about?", "")

if st.button("Ask MyAI Twin"):
    if not openai.api_key:
        st.warning("Please enter your OpenAI API key first!")
    elif user_input.strip() == "":
        st.warning("Please type something first.")
    else:
        with st.spinner("Thinking..."):
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "system", "content": "You are a helpful and intelligent AI Twin of the user."},
                          {"role": "user", "content": user_input}]
            )
            st.success("Here's what I think:")
            st.markdown(response['choices'][0]['message']['content'])

st.markdown("---")
st.caption("🧪 Made by Atharva • Powered by OpenAI • Streamlit Deployment")
